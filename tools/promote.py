"""העברת סביבת הבדיקות לסביבת האמת. מ-1.11.26 כל בקשה עולה לאמת מיד אחרי tools/stage.py (לבקשת בעל האתר: "תעלה תמיד את הכל לסביבת אמת מכאן").

שימוש:  python tools/backup-prod.py   (קודם: גיבוי נתוני האמת ותוכנית רולבק, כלל קבוע מ-31.10.26)
        python tools/promote.py
  0. שינויי בסיס נתונים (קבצי SQL שהשתנו): מסרב להעלות בלי גיבוי של public שנעשה ב-6 השעות האחרונות, על אותו קומיט שרץ עכשיו באמת.
     שינויי תצוגה בלבד (בלי SQL): בלי גיבוי ובלי תוכנית רולבק, מעלים ישר אחרי האישור (כלל מ-31.10.26).
  1. בודק שאין שינויים לא שמורים בענף staging (חוץ מסרטוני מודעות), ושסביבת הבדיקות פורסמה (tools/stage.py).
  2. main <- staging, דחיפה ל-origin main בלי לעבור ענף: האתר האמיתי (harpatka.co.il) מתעדכן.
  3. מסנכרן את staging עם main, כך ששתי הסביבות זהות.
  4. מדפיס את קבצי ה-SQL שהשתנו בדרך: הם הורצו רק על סכמת test, וצריך להריץ אותם גם על public.
  רולבק של נתונים לא מוחק מה שנכנס אחרי ההעלאה (ראו tools/restore-prod.py): אחרי הרצת ה-SQL על public מצלמים python tools/backup-prod.py --after.
"""
import os, pathlib, subprocess, sys

os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass
ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(*a, check=True, out=False):
    r = subprocess.run(a, cwd=ROOT, text=True, encoding='utf-8', capture_output=out, env=dict(os.environ, PYTHONIOENCODING='utf-8'))
    if check and r.returncode:
        sys.exit('נכשל: ' + ' '.join(a) + ('\n' + (r.stderr or '') if out else ''))
    return r.stdout.strip() if out else r.returncode


if run('git', 'rev-parse', '--abbrev-ref', 'HEAD', out=True) != 'staging':
    sys.exit('מריצים מתוך הענף staging')
if run('git', 'status', '--porcelain', '--untracked-files=no', '--', '.', ':(exclude)ads/video', ':(exclude)ads/videos.json', out=True):   # סרטונים שהרינדור מפרסם ברקע לא עוצרים העלאה
    sys.exit('יש שינויים שלא נשמרו בענף staging: קודם tools/stage.py')
run('git', 'fetch', '-q', 'origin')

# כלל קבוע (31.10.26): שינוי שנוגע בבסיס הנתונים (קבצי SQL) לא עולה בלי גיבוי נתוני האמת ותוכנית רולבק על המצב הנוכחי של האמת.
# שינויי תצוגה בלבד (בלי SQL) עולים ישר אחרי האישור, בלי גיבוי (לבקשת בעל האתר: "לא צריך להחמיר יותר מדי").
import datetime, json
sql = run('git', 'diff', '--name-only', 'origin/main...staging', '--', '*.sql', out=True)
prod = run('git', 'rev-parse', 'origin/main', out=True)
backup = None
if sql:
    for d in sorted((ROOT.parent / 'harpatka-backups').glob('*-prod'), reverse=True):
        try:
            m = json.loads((d / '_manifest.json').read_text(encoding='utf-8'))
        except Exception:
            continue
        age = datetime.datetime.now().astimezone() - datetime.datetime.fromisoformat(m['created_at'])
        if m.get('schema') == 'public' and m.get('prod_commit') == prod and age < datetime.timedelta(hours=6) and (d / 'ROLLBACK.md').exists():
            backup = d
            break
    if not backup:
        sys.exit('יש שינויי SQL ואין גיבוי עדכני של האמת על הקומיט ' + prod[:7] + ': קודם python tools/backup-prod.py')
    print('גיבוי ותוכנית רולבק: ' + str(backup))
else:
    print('שינויי תצוגה בלבד (בלי SQL): בלי גיבוי')

# בלי checkout: כמה שיחות והרינדור עובדים על אותה תיקייה, ומעבר ענף היה מחליף להם קבצים תוך כדי עבודה
if run('git', 'merge-base', '--is-ancestor', 'origin/main', 'staging', check=False) == 0:
    run('git', 'push', '-q', 'origin', 'staging:main')
else:
    # בענף main יש קומיט שאין ב-staging. כל מה שיש בו חייב להיות גם ב-staging (חוץ מסרטונים, שב-staging חדשים יותר), אחרת ממזגים ידנית
    base = run('git', 'merge-base', 'origin/main', 'staging', out=True)
    for path in run('git', '-c', 'core.quotepath=off', 'diff', '--name-only', base, 'origin/main', out=True).splitlines():
        if path.startswith('ads/video'):
            continue
        same = [subprocess.run(['git', 'rev-parse', f'{ref}:{path}'], cwd=ROOT, capture_output=True, text=True).stdout.strip() for ref in ('origin/main', 'staging')]
        if same[0] != same[1]:
            sys.exit('בענף main יש שינוי שאין ב-staging, צריך למזג ידנית: ' + path)
    new = run('git', 'commit-tree', 'staging^{tree}', '-p', 'origin/main', '-p', 'staging', '-m', 'העלאה לאמת מהבדיקות', '-m', 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>', out=True)
    run('git', 'push', '-q', 'origin', new + ':refs/heads/main')
    run('git', 'merge', '-q', '--ff-only', new, check=False)   # אותו עץ בדיוק, אז קובץ בתיקייה לא משתנה; אם נוסף בינתיים קומיט, ההעלאה הבאה תטפל בזה
run('git', 'push', '-q', 'origin', 'staging', check=False)
run('git', 'fetch', '-q', 'origin', 'main:main', check=False)
print('האמת עודכנה מהבדיקות (main = staging)')
if backup:
    mf = backup / '_manifest.json'
    m = json.loads(mf.read_text(encoding='utf-8'))
    m['promoted_to'] = run('git', 'rev-parse', 'origin/main', out=True)
    m['promoted_at'] = datetime.datetime.now().astimezone().isoformat(timespec='seconds')
    mf.write_text(json.dumps(m, ensure_ascii=False, indent=1), encoding='utf-8')
    print('לחזרה אחורה: ' + str(backup / 'ROLLBACK.md'))
    afters = [d for d in (ROOT.parent / 'harpatka-backups').glob('*-prod-after') if d.name > backup.name]
    if not afters:
        print('שימו לב: לא צולם צילום "אחרי" (python tools/backup-prod.py --after, מיד אחרי הרצת ה-SQL על public). בלעדיו רולבק של נתונים לא יכול להבדיל בין שינוי של ההעלאה לעריכות של משתמשים, ולכן לא ייגע בשורות קיימות.')
else:
    print('לחזרה אחורה (קוד בלבד): git revert של הקומיט בענף main')
if sql:
    print('קבצי SQL שהורצו רק על test וצריך להריץ גם על public:\n  ' + sql.replace('\n', '\n  '))
