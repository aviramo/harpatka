"""העברת סביבת הבדיקות לסביבת האמת. רק בבקשה מפורשת של בעל האתר.

שימוש:  python tools/promote.py
  1. בודק שאין שינויים לא שמורים בענף staging, ושסביבת הבדיקות פורסמה (tools/stage.py).
  2. main <- staging (merge), דחיפה ל-origin main: האתר האמיתי (harpatka.co.il) מתעדכן.
  3. מסנכרן את staging עם main וחוזר אליו, כך ששתי הסביבות זהות.
  4. מדפיס את קבצי ה-SQL שהשתנו בדרך: הם הורצו רק על סכמת test, וצריך להריץ אותם גם על public.
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
if run('git', 'status', '--porcelain', '--untracked-files=no', out=True):
    sys.exit('יש שינויים שלא נשמרו בענף staging: קודם tools/stage.py')
run('git', 'fetch', '-q', 'origin')
sql = run('git', 'diff', '--name-only', 'origin/main...staging', '--', '*.sql', out=True)
run('git', 'checkout', '-q', 'main')
run('git', 'pull', '-q', '--ff-only', 'origin', 'main')
run('git', 'merge', '-q', '--no-edit', 'staging')
run('git', 'push', '-q', 'origin', 'main')
run('git', 'checkout', '-q', 'staging')
run('git', 'merge', '-q', '--ff-only', 'main')
run('git', 'push', '-q', 'origin', 'staging')
print('האמת עודכנה מהבדיקות (main = staging)')
if sql:
    print('קבצי SQL שהורצו רק על test וצריך להריץ גם על public:\n  ' + sql.replace('\n', '\n  '))
