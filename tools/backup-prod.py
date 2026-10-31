"""גיבוי סביבת האמת לפני העלאה (כלל קבוע מ-31.10.26: אין העלאה לאמת בלי גיבוי ותוכנית רולבק).

שימוש:  python tools/backup-prod.py            (גיבוי של public, סביבת האמת)
        python tools/backup-prod.py --schema test   (לבדיקה של הכלי עצמו)
        python tools/backup-prod.py --after         (צילום נתונים אחרי הרצת ה-SQL על public ולפני/מיד אחרי ההעלאה; ראו למטה)

צילום "אחרי" (--after): רק הנתונים (בלי פונקציות וטריגרים), בתיקייה <תאריך>-prod-after. הוא מאפשר לרולבק של נתונים להבדיל בין מה ששינתה ההעלאה
לבין מה שמשתמשים ומנהלים שינו מאז, ולהחזיר רק את הראשון (tools/restore-prod.py --after). בלעדיו רולבק לא נוגע בשום שורה קיימת.

מה נשמר, בתיקייה מחוץ ל-repo (Desktop/harpatka-backups/<תאריך-שעה>-<schema>/), כי יש בה מידע אישי:
  <טבלה>.json      כל השורות של כל טבלאות harpatka_* (ערכים סודיים ב-harpatka_settings מוחלפים ב-***)
  _functions.sql   ההגדרות של כל הפונקציות harpatka_* (create or replace, אפשר להריץ כדי לשחזר פונקציה)
  _triggers.sql    הגדרות הטריגרים
  _policies.json   מדיניות ה-RLS
  _columns.json    העמודות של כל טבלה (מבנה הסכמה ברגע הגיבוי)
  _manifest.json   מתי, איזה קומיט רץ באמת, ספירת שורות לכל טבלה, סדר התלויות, קבצי ה-SQL שעומדים לרוץ
  ROLLBACK.md      תוכנית החזרה: קוד (git), נתונים (tools/restore-prod.py) ופונקציות
tools/promote.py מסרב להעלות בלי גיבוי של public שנעשה ב-6 השעות האחרונות על אותו קומיט של האמת.
"""
import datetime, json, os, pathlib, re, subprocess, sys, tempfile

os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass
ROOT = pathlib.Path(__file__).resolve().parent.parent
BACKUP_ROOT = ROOT.parent / 'harpatka-backups'
SECRET = re.compile(r'key|token|secret|pass|url', re.I)   # מפתחות ב-harpatka_settings שהערך שלהם לא נשמר בגיבוי


def sql(q):
    """מריץ שאילתה על המסד המקושר ומחזיר את השורות (רשימת מילונים)."""
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(q)
        path = f.name
    try:
        r = subprocess.run(['supabase', 'db', 'query', '--linked', '-f', path], cwd=ROOT, capture_output=True, shell=(os.name == 'nt'))
    finally:
        os.unlink(path)
    if r.returncode:
        sys.exit('השאילתה נכשלה:\n' + r.stderr.decode('utf-8', 'replace')[-1500:])
    return json.loads(r.stdout.decode('utf-8'))['rows']


def val(x):
    return json.loads(x) if isinstance(x, str) else x


def git(*a):
    return subprocess.run(['git', *a], cwd=ROOT, capture_output=True, text=True, encoding='utf-8').stdout.strip()


def main():
    schema = 'public'
    if '--schema' in sys.argv:
        schema = sys.argv[sys.argv.index('--schema') + 1]
    if schema not in ('public', 'test'):
        sys.exit('schema: public או test')
    lit = "'" + schema + "'"
    after = '--after' in sys.argv

    tables = [r['table_name'] for r in sql(
        "select table_name from information_schema.tables where table_schema = " + lit +
        " and table_name like 'harpatka\\_%' and table_type = 'BASE TABLE' order by 1;")]
    if not tables:
        sys.exit('לא נמצאו טבלאות')

    stamp = datetime.datetime.now().strftime('%Y-%m-%d-%H%M%S')
    out = BACKUP_ROOT / (stamp + '-' + ('prod' if schema == 'public' else schema) + ('-after' if after else ''))
    out.mkdir(parents=True, exist_ok=False)

    counts = {}
    for t in tables:
        rows = val(sql('select coalesce(json_agg(x), \'[]\'::json) as j from ' + schema + '.' + t + ' x;')[0]['j'])
        if t == 'harpatka_settings':   # בלי מפתחות סודיים בגיבוי
            for r in rows:
                if SECRET.search(str(r.get('key', ''))):
                    r['value'] = '***'
        (out / (t + '.json')).write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding='utf-8')
        counts[t] = len(rows)
        print(f'  {t}: {len(rows)}')

    if after:   # צילום "אחרי": רק הנתונים, בלי מבנה, לשימוש tools/restore-prod.py --after
        before = sorted(BACKUP_ROOT.glob('*-' + ('prod' if schema == 'public' else schema)), reverse=True)
        (out / '_manifest.json').write_text(json.dumps({
            'created_at': datetime.datetime.now().astimezone().isoformat(timespec='seconds'), 'schema': schema, 'kind': 'after-sql',
            'latest_before_backup': before[0].name if before else None, 'counts': counts}, ensure_ascii=False, indent=1), encoding='utf-8')
        print(f'\nצילום "אחרי" נשמר: {out}')
        print('לרולבק של נתונים: python tools/restore-prod.py "<תיקיית הגיבוי לפני>" --schema ' + schema + ' --after "' + str(out) + '" --dry')
        return

    cols = {}
    for r in sql("select table_name, column_name, data_type, is_nullable, column_default, is_generated from information_schema.columns "
                 "where table_schema = " + lit + " and table_name like 'harpatka\\_%' order by table_name, ordinal_position;"):
        cols.setdefault(r['table_name'], []).append({k: r[k] for k in ('column_name', 'data_type', 'is_nullable', 'column_default', 'is_generated')})
    (out / '_columns.json').write_text(json.dumps(cols, ensure_ascii=False, indent=1), encoding='utf-8')

    fns = sql("select p.proname, pg_get_functiondef(p.oid) as def from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
              "where n.nspname = " + lit + " and p.proname like 'harpatka\\_%' and p.prokind = 'f' order by 1;")
    (out / '_functions.sql').write_text(
        '-- הפונקציות כפי שהיו ברגע הגיבוי. להחזרה: supabase db query --linked -f _functions.sql\n\n' +
        '\n'.join(f['def'].rstrip() + ';\n' for f in fns), encoding='utf-8')

    trg = sql("select c.relname as tbl, t.tgname, pg_get_triggerdef(t.oid) as def from pg_trigger t join pg_class c on c.oid = t.tgrelid "
              "join pg_namespace n on n.oid = c.relnamespace where n.nspname = " + lit + " and not t.tgisinternal order by 1, 2;")
    (out / '_triggers.sql').write_text('\n'.join(f"-- {r['tbl']}\n{r['def']};" for r in trg) + '\n', encoding='utf-8')

    pol = sql("select tablename, policyname, cmd, roles::text as roles, qual, with_check from pg_policies where schemaname = " + lit + " order by 1, 2;")
    (out / '_policies.json').write_text(json.dumps(pol, ensure_ascii=False, indent=1), encoding='utf-8')

    # סדר תלויות (מפתחות זרים): ההורים קודם. משמש את tools/restore-prod.py
    deps = {t: set() for t in tables}
    for r in sql("select c.relname as child, p.relname as parent from pg_constraint k join pg_class c on c.oid = k.conrelid "
                 "join pg_class p on p.oid = k.confrelid join pg_namespace n on n.oid = c.relnamespace "
                 "where k.contype = 'f' and n.nspname = " + lit + ";"):
        if r['child'] in deps and r['parent'] in deps and r['child'] != r['parent']:
            deps[r['child']].add(r['parent'])
    order, left = [], dict(deps)
    while left:
        ready = sorted(t for t, d in left.items() if not (d & set(left)))
        if not ready:   # מעגל: מוסיפים את השאר לפי שם
            ready = sorted(left)
        order += ready
        for t in ready:
            left.pop(t)

    subprocess.run(['git', 'fetch', '-q', 'origin'], cwd=ROOT)
    prod = git('rev-parse', 'origin/main')
    staging = git('rev-parse', 'origin/staging')
    pending_sql = [x for x in git('diff', '--name-only', 'origin/main...origin/staging', '--', '*.sql').splitlines() if x]
    manifest = {
        'created_at': datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
        'schema': schema,
        'prod_commit': prod,
        'prod_commit_title': git('log', '-1', '--format=%s', 'origin/main'),
        'staging_commit': staging,
        'pending_sql_on_public': pending_sql,
        'counts': counts,
        'restore_order': order,
        'functions': len(fns), 'triggers': len(trg), 'policies': len(pol),
        'not_saved': 'ערכים סודיים ב-harpatka_settings (key / token / secret / url) מוחלפים ב-***; טבלאות auth של Supabase לא נכללות',
    }
    (out / '_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding='utf-8')

    short = prod[:7]
    sql_list = '\n'.join('- `' + s + '`' for s in pending_sql) or '- (אין)'
    (out / 'ROLLBACK.md').write_text(f"""# תוכנית רולבק, גיבוי {stamp}

מצב האמת ברגע הגיבוי: קומיט `{short}` ({manifest['prod_commit_title']}), סכמה `{schema}`.

## קבצי SQL שעומדים לרוץ על public בהעלאה הזו
{sql_list}

## 1. קוד (האתר ודף הניהול): החזרה לקומיט `{short}`
יוצר קומיט חדש שהתוכן שלו זהה ל-`{short}` (בלי force push), והאתר האמיתי מתעדכן תוך דקה:
```
git checkout main
git pull --ff-only origin main
git read-tree -u --reset {short}
git commit -m "rollback: האמת חוזרת לקומיט {short}"
git push origin main
git checkout staging
```
סביבת הבדיקות לא משתנה. כדי להחזיר אחר כך את מה שבוטל: `git revert <קומיט הרולבק>` על main ודחיפה.

## 2. נתונים: להחזיר רק מה שההעלאה שינתה, בלי לאבד מה שנכנס מאז
**כלל: רולבק לא מוחק ולא דורס הרשמות, תשלומים, הערות ועריכות שנעשו אחרי ההעלאה.** אחרי שההעלאה בחיים, נכנסות רשומות חדשות והמסד מתעדכן, ולכן אסור להחזיר טבלאות שלמות מהגיבוי.
כדי שהחזרה תוכל להבדיל בין שינוי של ההעלאה לשינוי של משתמש, צריך צילום נתונים שנעשה מיד אחרי הרצת ה-SQL על public (`python tools/backup-prod.py --after`, נשמר ב-`<תאריך>-prod-after`).
קודם בדיקה יבשה (טרנזקציה שמתבטלת, לא משנה כלום), ואז באמת:
```
python tools/restore-prod.py "{out}" --schema public --after "<תיקיית ה-prod-after>" --dry
python tools/restore-prod.py "{out}" --schema public --after "<תיקיית ה-prod-after>" --yes
```
מה זה עושה: שורות שנוצרו אחרי ההעלאה לא נוגעים בהן. עמודה שההעלאה שינתה ועוד לא שונתה מאז חוזרת לערך הגיבוי. עמודה ששונתה מאז נשארת כפי שהיא. שורה שההעלאה מחקה מוחזרת, ושורה שנמחקה אחרי ההעלאה נשארת מחוקה. ההדפסה מראה בכל טבלה כמה עמודות הוחזרו, כמה שינויים מאוחרים נשמרו וכמה שורות חדשות נשארו.
בלי `--after` הכלי לא נוגע בשורות קיימות (רק מדווח), כי אי אפשר לדעת מי שינה אותן. אפשר להחזיר רק חלק מהטבלאות: `--tables harpatka_attendance,harpatka_payments`.
**אסור** `--mode replace --wipe-new-data` (מחיקה והחלפה של הטבלאות) אלא באסון, אחרי גיבוי חדש ובבקשה מפורשת: הוא מוחק כל מה שנכנס אחרי הגיבוי.
`harpatka_settings` לא מוחזרת (המפתחות הסודיים לא נשמרו בגיבוי).

## 3. מבנה המסד (פונקציות, טריגרים, עמודות)
- פונקציות: `supabase db query --linked -f "{out / '_functions.sql'}"` מחזיר כל פונקציה להגדרה שהייתה ברגע הגיבוי.
- טבלאות ועמודות חדשות שנוספו בהעלאה הן תוספות: הקוד הישן מתעלם מהן, ואין צורך למחוק אותן.
- הטריגרים ומדיניות ה-RLS כפי שהיו: `_triggers.sql`, `_policies.json`.
""", encoding='utf-8')

    print(f'\nהגיבוי נשמר: {out}')
    print(f'קומיט האמת: {short}  ·  {sum(counts.values())} שורות ב-{len(counts)} טבלאות  ·  {len(fns)} פונקציות')
    print('תוכנית הרולבק: ' + str(out / 'ROLLBACK.md'))


if __name__ == '__main__':
    main()
