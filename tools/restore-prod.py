"""החזרת נתונים מגיבוי של tools/backup-prod.py (חלק מתוכנית הרולבק).

כלל (31.10.26): רולבק לא מוחק ולא דורס מה שנכנס או השתנה אחרי ההעלאה (הרשמות, תשלומים, הערות, עריכות של מנהלים).
ברירת המחדל היא לכן מיזוג, לא החלפה של טבלאות שלמות.

שימוש:
  python tools/restore-prod.py <גיבוי לפני> --schema public --after <צילום אחרי ה-SQL> --dry   בדיקה יבשה (טרנזקציה שמתבטלת, שום דבר לא משתנה)
  python tools/restore-prod.py <גיבוי לפני> --schema public --after <צילום אחרי ה-SQL> --yes   החזרה אמיתית לאמת
  --tables a,b   רק חלק מהטבלאות

מיזוג (ברירת מחדל), לכל שורה בגיבוי (לפי המפתח הראשי):
  * שורה שנוצרה אחרי הגיבוי: לא נוגעים בה.
  * עמודה ששינתה ההעלאה (ערך הגיבוי שונה מצילום "אחרי") ועוד לא שונתה מאז (הערך הנוכחי זהה לצילום "אחרי"): חוזרת לערך הגיבוי.
  * עמודה ששונתה אחרי ההעלאה (הערך הנוכחי שונה מצילום "אחרי"): נשארת כפי שהיא עכשיו.
  * שורה שההעלאה מחקה (יש בגיבוי, אין בצילום "אחרי") ואין עכשיו: מוחזרת. שורה שנמחקה אחרי ההעלאה (יש בצילום "אחרי"): נשארת מחוקה.
  בלי --after אי אפשר להבדיל בין שינוי של ההעלאה לשינוי של משתמש, ולכן לא נוגעים בשום שורה קיימת (רק מדווחים), אלא אם מבקשים במפורש:
  --overwrite-changed   להחזיר לערך הגיבוי כל עמודה שונה (דורס עריכות שנעשו מאז, לא מוחק שורות)
  --restore-deleted     להחזיר שורות שיש בגיבוי ואין עכשיו (בלי --after)
החלפה מלאה (ישנה, מוחקת כל מה שנכנס אחרי הגיבוי): --mode replace --wipe-new-data. רק לאסון, ורק בבקשה מפורשת, אחרי גיבוי חדש.

הטריגרים של הטבלאות מושבתים בזמן ההחזרה (בלי הערות מערכת, מיילים ויומן). אם משהו נכשל, הכול מתבטל.
לא מוחזרות: harpatka_settings (המפתחות הסודיים לא נשמרו בגיבוי) ו-harpatka_audit (יומן הביקורת נשאר), אלא אם מבקשים אותן ב---tables.
"""
import json, os, pathlib, re, secrets, subprocess, sys, tempfile

os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass
ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP = {'harpatka_settings', 'harpatka_audit'}
LIMIT = 600_000   # בתים לבקשה אחת (לשירות השאילתות של Supabase יש מגבלת גודל)


def arg(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith('--'):
        sys.exit(__doc__)
    src = pathlib.Path(sys.argv[1])
    man = json.loads((src / '_manifest.json').read_text(encoding='utf-8'))
    schema = arg('--schema')
    if schema not in ('public', 'test'):
        sys.exit('חובה --schema public או --schema test')
    dry = '--dry' in sys.argv
    if schema == 'public' and not dry and '--yes' not in sys.argv:
        sys.exit('החזרה אמיתית לאמת דורשת --yes (או --dry לבדיקה יבשה)')
    mode = arg('--mode') or 'merge'
    if mode not in ('merge', 'replace'):
        sys.exit('--mode merge או replace')
    if mode == 'replace' and '--wipe-new-data' not in sys.argv:
        sys.exit('החלפה מלאה מוחקת כל מה שנכנס אחרי הגיבוי (הרשמות, תשלומים, הערות). אם זה באמת מה שצריך: --mode replace --wipe-new-data')
    after = pathlib.Path(arg('--after')) if arg('--after') else None
    if after and not (after / '_manifest.json').exists():
        sys.exit('תיקיית --after לא נראית כמו צילום של tools/backup-prod.py --after')
    want = [t.strip() for t in (arg('--tables') or '').split(',') if t.strip()]
    order = [t for t in man['restore_order'] if (t in want if want else t not in SKIP) and (src / (t + '.json')).exists()]
    if not order:
        sys.exit('אין טבלאות להחזרה')

    # שלב 1: הנתונים עולים במנות לטבלת ביניים בסכמה hk_restore (לא חשופה לאתר), כי לבקשה אחת יש מגבלת גודל
    run_b = 'r' + secrets.token_hex(6)
    run_m = ('m' + secrets.token_hex(6)) if after else None
    q('create schema if not exists hk_restore; revoke all on schema hk_restore from public;'
      ' create table if not exists hk_restore.chunks (run text, tbl text, part int, data jsonb, primary key (run, tbl, part));')
    try:
        parts = upload(run_b, src, order)
        if after:
            parts += upload(run_m, after, [t for t in order if (after / (t + '.json')).exists()])
        print(f'  הנתונים הועלו לטבלת הביניים ({parts} מנות)')
        if mode == 'merge':
            out = restore_merge(run_b, run_m, schema, order, dry, '--restore-deleted' in sys.argv, '--overwrite-changed' in sys.argv)
            report_merge(out, order, dry, schema, man, bool(after))
        else:
            out = restore_replace(run_b, schema, order, dry)
            report_replace(out, man, order, dry, schema)
    finally:
        q(f"delete from hk_restore.chunks where run in ('{run_b}'" + (f", '{run_m}'" if run_m else '') + "); do $x$ begin if not exists (select 1 from hk_restore.chunks) then drop schema hk_restore cascade; end if; end $x$;")


def upload(run, src, order):
    batch, size, part = [], 0, 0
    for t in order:
        rows = json.loads((src / (t + '.json')).read_text(encoding='utf-8'))
        chunk, csize = [], 0
        for row in rows + [None]:
            s = json.dumps(row, ensure_ascii=False) if row is not None else ''
            if row is None or (chunk and csize + len(s.encode()) > LIMIT):
                if chunk or not rows:
                    data = json.dumps(chunk, ensure_ascii=False)
                    tag = 'hk' + secrets.token_hex(6)
                    while tag in data:
                        tag = 'hk' + secrets.token_hex(6)
                    stmt = f"insert into hk_restore.chunks values ('{run}', '{t}', {part}, ${tag}${data}${tag}$::jsonb);"
                    part += 1
                    if batch and size + len(stmt.encode()) > LIMIT:
                        q('\n'.join(batch))
                        batch, size = [], 0
                    batch.append(stmt)
                    size += len(stmt.encode())
                chunk, csize = [], 0
            if row is not None:
                chunk.append(row)
                csize += len(s.encode())
    if batch:
        q('\n'.join(batch))
    return part


def q(text, check=True):
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(text)
        path = f.name
    try:
        r = subprocess.run(['supabase', 'db', 'query', '--linked', '-f', path], cwd=ROOT, capture_output=True, shell=(os.name == 'nt'))
    finally:
        os.unlink(path)
    out = r.stderr.decode('utf-8', 'replace') + '\n' + r.stdout.decode('utf-8', 'replace')   # השגיאה של השאילתה עלולה להגיע גם בפלט הרגיל
    if check and (r.returncode or '"_tag":"Error"' in out):
        sys.exit('שאילתה נכשלה:\n' + out[-2000:])
    return r.returncode, out


def tf(x):
    return 'true' if x else 'false'


def restore_merge(run_b, run_m, schema, order, dry, reinsert, overwrite):
    """מיזוג: מחזיר רק מה שההעלאה שינתה, ולא נוגע במה שנוצר או שונה אחריה. מחזיר את הפלט (ההודעה HK_DRY_OK / HK_DONE עם הספירות)."""
    arr = 'array[' + ', '.join("'" + t + "'" for t in order) + ']::text[]'
    rm = f"'{run_m}'" if run_m else "''"
    text = f"""do $hkdo$
declare
  sch text := '{schema}'; ord text[] := {arr}; dry boolean := {tf(dry)}; hasm boolean := {tf(bool(run_m))}; reins boolean := {tf(reinsert)}; ovw boolean := {tf(overwrite)};
  t text; pk text[]; gen text[]; pkc text; b jsonb; m jsonb; cur jsonb; k text; cols text;
  n_upd bigint; n_ins bigint; n_conf bigint; n_here bigint; n_cur bigint; res jsonb := '{{}}'::jsonb; skipped text[];
begin
  skipped := array(select x from unnest(ord) x where to_regclass(format('%I.%I', sch, x)) is null);
  ord := array(select x from unnest(ord) with ordinality u(x, i) where to_regclass(format('%I.%I', sch, x)) is not null order by i);
  foreach t in array ord loop execute format('alter table %I.%I disable trigger user', sch, t); end loop;
  foreach t in array ord loop
    select array_agg(a.attname::text order by a.attnum) into pk from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
     where i.indrelid = format('%I.%I', sch, t)::regclass and i.indisprimary;
    select coalesce(array_agg(ic.column_name::text), '{{}}') into gen from information_schema.columns ic where ic.table_schema = sch and ic.table_name = t and ic.is_generated <> 'NEVER';
    n_upd := 0; n_ins := 0; n_conf := 0; n_here := 0;
    if pk is null then res := res || jsonb_build_object(t, jsonb_build_object('no_pk', true)); continue; end if;
    for b in select e from hk_restore.chunks ch, jsonb_array_elements(ch.data) e where ch.run = '{run_b}' and ch.tbl = t loop
      pkc := (select string_agg(format('%I::text = %L', x, b->>x), ' and ') from unnest(pk) x);
      execute format('select to_jsonb(x) from %I.%I x where %s', sch, t, pkc) into cur;
      m := null;
      if hasm then
        select e into m from hk_restore.chunks ch, jsonb_array_elements(ch.data) e
         where ch.run = {rm} and ch.tbl = t and (select bool_and(e->>x is not distinct from b->>x) from unnest(pk) x) limit 1;
      end if;
      if cur is null then
        -- שורה שיש בגיבוי ואין עכשיו: מוחזרת אם ההעלאה מחקה אותה (אין בצילום אחרי), או לפי בקשה; שורה שנמחקה אחרי ההעלאה נשארת מחוקה
        if (hasm and m is null) or (not hasm and reins) then
          select string_agg(format('%I', k2), ', ') into cols from jsonb_object_keys(b) k2
           where k2 <> all(gen) and exists (select 1 from information_schema.columns ic where ic.table_schema = sch and ic.table_name = t and ic.column_name = k2);
          execute format('insert into %I.%I (%s) overriding system value select %s from jsonb_populate_record(null::%I.%I, %L::jsonb)', sch, t, cols, cols, sch, t, b::text);
          n_ins := n_ins + 1;
        end if;
      else
        n_here := n_here + 1;
        for k in select jsonb_object_keys(b) loop
          if k = any(pk) or k = any(gen) or b->k is not distinct from cur->k then continue; end if;
          if not exists (select 1 from information_schema.columns ic where ic.table_schema = sch and ic.table_name = t and ic.column_name = k) then continue; end if;
          if (hasm and m is not null and m->k is not distinct from cur->k and m->k is distinct from b->k) or (not hasm and ovw) then
            execute format('update %I.%I set %I = (jsonb_populate_record(null::%I.%I, %L::jsonb)).%I where %s', sch, t, k, sch, t, jsonb_build_object(k, b->k)::text, k, pkc);
            n_upd := n_upd + 1;
          else
            n_conf := n_conf + 1;
          end if;
        end loop;
      end if;
    end loop;
    execute format('select count(*) from %I.%I', sch, t) into n_cur;
    res := res || jsonb_build_object(t, jsonb_build_object('upd', n_upd, 'ins', n_ins, 'conf', n_conf, 'new', greatest(n_cur - n_here - n_ins, 0)));
  end loop;
  foreach t in array ord loop execute format('alter table %I.%I enable trigger user', sch, t); end loop;
  if array_length(skipped, 1) > 0 then res := res || jsonb_build_object('_missing_in_target', to_jsonb(skipped)); end if;
  if dry then raise exception 'HK_DRY_OK %', res; end if;
  raise notice 'HK_DONE %', res;
end $hkdo$;
select 'ok' as status;"""
    rc, out = q(text, check=False)
    if dry:
        if 'HK_DRY_OK' not in out:
            sys.exit('הבדיקה היבשה נכשלה:\n' + out[-2000:])
    elif rc or '"_tag":"Error"' in out:
        sys.exit('ההחזרה נכשלה ושום דבר לא השתנה:\n' + out[-2000:])
    return out


def parse_result(out):
    """מוציא את מילון הספירות מההודעה (היא עלולה להגיע מקודדת, עם \\")."""
    txt = re.sub(r'\\+', '', re.split(r'HK_(?:DRY_OK|DONE)', out, 1)[1])   # מסירים את כל ה-backslash של הקידוד (ההודעה מגיעה מקודדת כמה פעמים)
    i = txt.index('{')
    depth = 0
    for j in range(i, len(txt)):
        depth += txt[j] == '{'
        depth -= txt[j] == '}'
        if depth == 0:
            return json.loads(txt[i:j + 1])
    raise ValueError('לא נמצאו הספירות בפלט')


def report_merge(out, order, dry, schema, man, has_after):
    try:
        res = parse_result(out)
    except Exception as e:
        print('  (לא הצלחתי לקרוא את הספירות מהפלט: ' + str(e) + ')')
        res = {}
    tot = {'upd': 0, 'ins': 0, 'conf': 0, 'new': 0}
    for t in order:
        r = res.get(t)
        if not isinstance(r, dict):
            continue
        if r.get('no_pk'):
            print(f'  {t}: אין מפתח ראשי, דולגה')
            continue
        for k in tot:
            tot[k] += r.get(k, 0)
        if any(r.get(k) for k in tot):
            note = 'שונו מאז ונשארו כפי שהן' if has_after else 'שונות מהגיבוי ולא נגעתי'
            print(f'  {t}: עמודות שהוחזרו {r["upd"]}, שורות שהוחזרו {r["ins"]}, עמודות ' + note + f' {r["conf"]}, שורות חדשות שנשארו {r["new"]}')
    miss = res.get('_missing_in_target')
    if miss:
        print('  לא קיימות ביעד (דולגו): ' + ', '.join(miss))
    print(f'\nסך הכול: עמודות שהוחזרו {tot["upd"]}, שורות שהוחזרו {tot["ins"]}, עמודות ' + ('שונו מאז ונשארו' if has_after else 'שונות מהגיבוי ולא נגעתי') + f' {tot["conf"]}, שורות חדשות שלא נגעתי בהן {tot["new"]}')
    if not has_after and tot['conf']:
        print('הערה: בלי --after אי אפשר להבדיל בין שינוי של ההעלאה לעריכה של משתמש, ולכן לא נגעתי בעמודות השונות. (צילום אחרי ה-SQL: python tools/backup-prod.py --after)')
    print(('\nבדיקה יבשה: ' if dry else f'\nבוצע בסכמה {schema}: ') + 'שום שורה לא נמחקה' + (', ושום דבר לא השתנה' if dry else '') + f' (גיבוי מ-{man["created_at"]})')


def restore_replace(run, schema, order, dry):
    """החלפה מלאה (מסוכנת): מרוקנת את הטבלאות וממלאת מהגיבוי. מוחקת כל מה שנכנס אחרי הגיבוי."""
    arr = 'array[' + ', '.join("'" + t + "'" for t in order) + ']::text[]'
    # בתוך מחרוזת של format() במסד, ולכן הגרשיים כפולים
    rows_of = f"(select coalesce(jsonb_agg(e), ''[]''::jsonb) from hk_restore.chunks ch, jsonb_array_elements(ch.data) e where ch.run = ''{run}'' and ch.tbl = %L)"
    text = f"""do $hkdo$
declare
  sch text := '{schema}';
  ord text[] := {arr};
  dry boolean := {tf(dry)};
  t text; cols text; n bigint; res jsonb := '{{}}'::jsonb; c record; skipped text[] := '{{}}';
begin
  skipped := array(select x from unnest(ord) x where to_regclass(format('%I.%I', sch, x)) is null);
  ord := array(select x from unnest(ord) with ordinality u(x, i) where to_regclass(format('%I.%I', sch, x)) is not null order by i);
  foreach t in array ord loop execute format('alter table %I.%I disable trigger user', sch, t); end loop;
  execute 'truncate table ' || (select string_agg(format('%I.%I', sch, x), ', ') from unnest(ord) x) || ' restart identity';
  foreach t in array ord loop
    select string_agg(format('%I', ic.column_name), ', ' order by ic.ordinal_position) into cols
      from information_schema.columns ic
     where ic.table_schema = sch and ic.table_name = t and ic.is_generated = 'NEVER'
       and ic.column_name in (select distinct k from hk_restore.chunks ch, jsonb_array_elements(ch.data) e, jsonb_object_keys(e) k where ch.run = '{run}' and ch.tbl = t);
    n := 0;
    if cols is not null then
      execute format('insert into %I.%I (%s) overriding system value select %s from jsonb_populate_recordset(null::%I.%I, {rows_of})', sch, t, cols, cols, sch, t, t);
      get diagnostics n = row_count;
    end if;
    res := res || jsonb_build_object(t, n);
    if not dry then   -- setval לא מתבטל ב-rollback, ולכן רק בהחזרה אמיתית
      for c in select ic.column_name, pg_get_serial_sequence(format('%I.%I', sch, t), ic.column_name) as seq
                 from information_schema.columns ic where ic.table_schema = sch and ic.table_name = t loop
        if c.seq is not null then
          execute format('select setval(%L, coalesce((select max(%I) from %I.%I), 1), (select max(%I) from %I.%I) is not null)', c.seq, c.column_name, sch, t, c.column_name, sch, t);
        end if;
      end loop;
    end if;
  end loop;
  foreach t in array ord loop execute format('alter table %I.%I enable trigger user', sch, t); end loop;
  if array_length(skipped, 1) > 0 then res := res || jsonb_build_object('_missing_in_target', to_jsonb(skipped)); end if;
  if dry then raise exception 'HK_DRY_OK %', res; end if;
  raise notice 'HK_DONE %', res;
end $hkdo$;
select 'ok' as status;"""
    rc, out = q(text, check=False)
    if dry:
        if 'HK_DRY_OK' not in out:
            sys.exit('הבדיקה היבשה נכשלה:\n' + out[-2000:])
    elif rc or '"_tag":"Error"' in out:
        sys.exit('ההחזרה נכשלה ושום דבר לא השתנה:\n' + out[-2000:])
    return out


def report_replace(out, man, order, dry, schema):
    if dry:
        txt = out.split('HK_DRY_OK', 1)[1]   # ההודעה עלולה להגיע מקודדת (\") ולכן קוראים את הספירות בביטוי רגולרי
        got = {k: int(v) for k, v in re.findall(r'(harpatka_\w+)[\\"]*\s*:\s*(\d+)', txt)}
        miss = re.search(r'_missing_in_target[\\"]*\s*:\s*\[([^\]]*)\]', txt)
        if miss:
            got['_missing_in_target'] = re.findall(r'harpatka_\w+', miss.group(1))
    else:
        got = {t: None for t in order}
    bad = []
    for t in order:
        exp = man['counts'].get(t)
        g = got.get(t)
        if t in got.get('_missing_in_target', []):
            continue
        mark = '' if (g is None and not dry) or g == exp else '  <-- שונה'
        if mark:
            bad.append(t)
        print(f'  {t}: בגיבוי {exp}' + ('' if g is None else f', הוחזרו {g}') + mark)
    if got.get('_missing_in_target'):
        print('  לא קיימות ביעד (דולגו): ' + ', '.join(got['_missing_in_target']))
    if dry:
        print('\nבדיקה יבשה' + (' עברה: כל השורות נכנסו, ושום דבר לא השתנה' if not bad else ' עם הבדלים, לבדוק לפני החזרה אמיתית'))
    else:
        print(f'\nהנתונים בסכמה {schema} הוחזרו לגיבוי מ-{man["created_at"]} (כל מה שנכנס אחרי הגיבוי נמחק)')


if __name__ == '__main__':
    main()
