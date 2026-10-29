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

# בדיקת תחביר לפני כל פרסום: קבצי JS ובלוקי script בתוך HTML (גרסה שבורה לא עולה לאוויר)
import re, tempfile, shutil
if shutil.which('node'):
    for f in files:
        if not f.endswith(('.js', '.html')): continue   # קבצים בינאריים (וידאו, תמונות) לא נקראים כטקסט
        src = (ROOT / f).read_text(encoding='utf-8')
        if f.endswith('.js'): blocks = [src]
        elif f.endswith('.html'): blocks = [m.group(1) for m in re.finditer(r'<script(?![^>]*src=)[^>]*>(.*?)</script>', src, re.S) if m.group(1).strip() and 'application/ld+json' not in m.group(0)[:200]]
        else: continue
        for i, b in enumerate(blocks):
            with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as tf: tf.write(b); tn = tf.name
            r = subprocess.run(['node', '--check', tn], capture_output=True, text=True, encoding='utf-8')
            os.unlink(tn)
            if r.returncode: sys.exit('שגיאת תחביר ב-' + f + ' (בלוק ' + str(i) + '), לא מפרסם: ' + r.stderr[:400])

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
