"""החזרת נתונים מגיבוי של tools/backup-prod.py (חלק מתוכנית הרולבק).

שימוש:
  python tools/restore-prod.py <תיקיית הגיבוי> --schema public --dry    בדיקה יבשה: הכול רץ בטרנזקציה שמתבטלת בסוף, שום דבר לא משתנה
  python tools/restore-prod.py <תיקיית הגיבוי> --schema public --yes    החזרה אמיתית לאמת
  --tables a,b   רק חלק מהטבלאות (טבלה שטבלה אחרת מצביעה עליה דורשת לכלול גם אותה)

מה קורה: בטרנזקציה אחת, הטריגרים של הטבלאות מושבתים (בלי הערות מערכת, מיילים ויומן), הטבלאות מתרוקנות ומתמלאות
מחדש מהגיבוי לפי סדר התלויות, והמונים (sequences) מתעדכנים. אם משהו נכשל, הכול מתבטל.
לא מוחזרות: harpatka_settings (המפתחות הסודיים לא נשמרו בגיבוי) ו-harpatka_audit (יומן הביקורת נשאר עם כל מה שקרה), אלא אם מבקשים אותן ב---tables.
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
    want = [t.strip() for t in (arg('--tables') or '').split(',') if t.strip()]
    order = [t for t in man['restore_order'] if (t in want if want else t not in SKIP) and (src / (t + '.json')).exists()]
    if not order:
        sys.exit('אין טבלאות להחזרה')

    # שלב 1: הנתונים עולים במנות לטבלת ביניים בסכמה hk_restore (לא חשופה לאתר), כי לבקשה אחת יש מגבלת גודל
    run = 'r' + secrets.token_hex(6)
    q('create schema if not exists hk_restore; revoke all on schema hk_restore from public;'
      ' create table if not exists hk_restore.chunks (run text, tbl text, part int, data jsonb, primary key (run, tbl, part));')
    try:
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
        print(f'  הנתונים הועלו לטבלת הביניים ({part} מנות)')
        r = restore(run, schema, order, dry)
    finally:
        q(f"delete from hk_restore.chunks where run = '{run}'; do $x$ begin if not exists (select 1 from hk_restore.chunks) then drop schema hk_restore cascade; end if; end $x$;")
    report(r, man, order, dry, schema)


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


def restore(run, schema, order, dry):
    """שלב 2: טרנזקציה אחת שמרוקנת וממלאת את הטבלאות מטבלת הביניים. מחזיר את הפלט (בבדיקה יבשה ההודעה HK_DRY_OK עם הספירות)."""
    arr = 'array[' + ', '.join("'" + t + "'" for t in order) + ']::text[]'
    # בתוך מחרוזת של format() במסד, ולכן הגרשיים כפולים
    rows_of = f"(select coalesce(jsonb_agg(e), ''[]''::jsonb) from hk_restore.chunks ch, jsonb_array_elements(ch.data) e where ch.run = ''{run}'' and ch.tbl = %L)"
    text = f"""do $hkdo$
declare
  sch text := '{schema}';
  ord text[] := {arr};
  dry boolean := {'true' if dry else 'false'};
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


def report(out, man, order, dry, schema):
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
        print(f'\nהנתונים בסכמה {schema} הוחזרו לגיבוי מ-{man["created_at"]}')


if __name__ == '__main__':
    main()
