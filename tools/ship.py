"""פרסום בסדר קבוע: קודם סביבת הבדיקות, ורק אחריה סביבת האמת.

שימוש:  python tools/ship.py "הודעת קומיט" קובץ1 קובץ2 ...
  1. בונה ודוחף את סביבת הבדיקות (tools/deploy-test.py, נבנה מהקבצים שבתיקייה, לפני קומיט).
  2. אם נכשל: עוצר ולא נוגע בסביבת האמת.
  3. רק אם הצליח: git add לקבצים הנתונים (בשמם, לעולם לא -A), קומיט (עם Co-Authored-By) ודחיפה ל-main (סביבת האמת).
"""
import subprocess, sys, pathlib, os

os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
TRAILER = 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'


def run(*a, check=True):
    r = subprocess.run(a, cwd=ROOT, text=True, encoding='utf-8', env=dict(os.environ, PYTHONIOENCODING='utf-8'))
    if check and r.returncode:
        sys.exit('נכשל: ' + ' '.join(a))
    return r.returncode


if len(sys.argv) < 3:
    sys.exit('שימוש: python tools/ship.py "הודעת קומיט" קובץ [קובץ ...]')
msg, files = sys.argv[1], sys.argv[2:]
for f in files:
    if f in ('-A', '.', '--all') or not (ROOT / f).exists():
        sys.exit('קובץ לא תקין (מוסיפים רק קבצים בשמם): ' + f)

print('1/2 סביבת בדיקות...')
run(sys.executable, str(ROOT / 'tools' / 'deploy-test.py'))
print('2/2 סביבת האמת...')
run('git', 'add', *files)
if run('git', 'diff', '--cached', '--quiet', check=False) == 0:
    print('אין שינוי לקומיט'); sys.exit(0)
run('git', 'commit', '-q', '-m', msg, '-m', TRAILER)
run('git', 'pull', '--rebase', '--autostash', '-q', 'origin', 'main')
run('git', 'push', '-q', 'origin', 'main')
print('פורסם: בדיקות ואז אמת')
