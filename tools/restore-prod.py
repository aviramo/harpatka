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

    parts = ['create temp table _hk_restore (tbl text primary key, data jsonb) on commit drop;']
    for t in order:
        data = (src / (t + '.json')).read_text(encoding='utf-8')
        tag = 'hk' + secrets.token_hex(6)
        while tag in data:
            tag = 'hk' + secrets.token_hex(6)
        parts.append(f"insert into _hk_restore values ('{t}', ${tag}${data}${tag}$::jsonb);")
    arr = 'array[' + ', '.join("'" + t + "'" for t in order) + ']::text[]'
    parts.append(f"""do $hkdo$
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
       and ic.column_name in (select distinct k from _hk_restore r, jsonb_array_elements(r.data) e, jsonb_object_keys(e) k where r.tbl = t);
    n := 0;
    if cols is not null then
      execute format('insert into %I.%I (%s) overriding system value select %s from jsonb_populate_recordset(null::%I.%I, (select data from _hk_restore where tbl = %L))', sch, t, cols, cols, sch, t, t);
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
end $hkdo$;""")
    parts.append("select 'ok' as status;")

    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write('\n'.join(parts))
        path = f.name
    try:
        r = subprocess.run(['supabase', 'db', 'query', '--linked', '-f', path], cwd=ROOT, capture_output=True, shell=(os.name == 'nt'))
    finally:
        os.unlink(path)
    err = r.stderr.decode('utf-8', 'replace')
    if dry:
        if 'HK_DRY_OK' not in err:
            sys.exit('הבדיקה היבשה נכשלה:\n' + err[-2000:])
        txt = err.split('HK_DRY_OK', 1)[1]   # ההודעה עלולה להגיע מקודדת (\") ולכן קוראים את הספירות בביטוי רגולרי
        got = {k: int(v) for k, v in re.findall(r'(harpatka_\w+)\\?"\s*:\s*(\d+)', txt)}
        miss = re.search(r'_missing_in_target\\?"\s*:\s*\[([^\]]*)\]', txt)
        if miss:
            got['_missing_in_target'] = re.findall(r'harpatka_\w+', miss.group(1))
    else:
        if r.returncode:
            sys.exit('ההחזרה נכשלה ושום דבר לא השתנה:\n' + err[-2000:])
        got = {t: None for t in order}
    bad = []
    for t in order:
        exp = man['counts'].get(t)
        g = got.get(t)
        mark = '' if g is None or g == exp else '  <-- שונה'
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
