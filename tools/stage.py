"""כלל עבודה מ-30.10.26: כל בקשה עובדת רק על סביבת הבדיקות (https://test.harpatka.co.il), בכל הדפים: האתר הציבורי ודף הניהול.

שימוש:  python tools/stage.py "הודעת קומיט" קובץ1 קובץ2 ...
  1. עובדים בענף staging (לא main). אם הענף הנוכחי אחר: עוצר.
  2. בדיקת תחביר ל-JS ולבלוקי script ב-HTML (גרסה שבורה לא עולה).
  3. בונה ודוחף את סביבת הבדיקות (tools/deploy-test.py, מהקבצים שבתיקייה).
  4. git add לקבצים בשמם (לעולם לא -A), קומיט ודחיפה ל-origin staging (גיבוי והיסטוריה).
     GitHub Pages של האתר האמיתי בונה רק מ-main, ולכן האתר האמיתי לא משתנה.
העברה לאמת רק בבקשה מפורשת של בעל האתר: python tools/promote.py
"""
import os, pathlib, re, shutil, subprocess, sys, tempfile

os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
BRANCH = 'staging'


def run(*a, check=True, out=False):
    r = subprocess.run(a, cwd=ROOT, text=True, encoding='utf-8', capture_output=out, env=dict(os.environ, PYTHONIOENCODING='utf-8'))
    if check and r.returncode:
        sys.exit('נכשל: ' + ' '.join(a) + ('\n' + (r.stderr or '') if out else ''))
    return r.stdout.strip() if out else r.returncode


def syntax_check(files):
    if not shutil.which('node'):
        return
    for f in files:
        if not f.endswith(('.js', '.html')):
            continue
        src = (ROOT / f).read_text(encoding='utf-8')
        blocks = [src] if f.endswith('.js') else [m.group(1) for m in re.finditer(r'<script(?![^>]*src=)[^>]*>(.*?)</script>', src, re.S)
                                                   if m.group(1).strip() and 'application/ld+json' not in m.group(0)[:200]]
        for i, b in enumerate(blocks):
            with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as tf:
                tf.write(b); tn = tf.name
            r = subprocess.run(['node', '--check', tn], capture_output=True, text=True, encoding='utf-8')
            os.unlink(tn)
            if r.returncode:
                sys.exit('שגיאת תחביר ב-' + f + ' (בלוק ' + str(i) + '), לא מפרסם: ' + r.stderr[:400])


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit('שימוש: python tools/stage.py "הודעת קומיט" קובץ [קובץ ...]')
    msg, files = sys.argv[1], sys.argv[2:]
    cur = run('git', 'rev-parse', '--abbrev-ref', 'HEAD', out=True)
    if cur != BRANCH:
        sys.exit(f'הענף הנוכחי הוא {cur}. עובדים בענף {BRANCH} (git checkout {BRANCH}); האמת מתעדכנת רק ב-tools/promote.py, בבקשה מפורשת')
    for f in files:
        if f in ('-A', '.', '--all') or not (ROOT / f).exists() and run('git', 'ls-files', '--error-unmatch', f, check=False, out=True) == '':
            sys.exit('קובץ לא תקין (מוסיפים רק קבצים בשמם): ' + f)
    syntax_check(files)
    print('1/2 סביבת בדיקות...')
    run(sys.executable, str(ROOT / 'tools' / 'deploy-test.py'))
    print('2/2 שמירה בענף staging...')
    run('git', 'add', '-A', '--', *files)
    if run('git', 'diff', '--cached', '--quiet', check=False) == 0:
        print('אין שינוי לקומיט'); sys.exit(0)
    run('git', 'commit', '-q', '-m', msg, '-m', TRAILER)
    run('git', 'push', '-q', 'origin', BRANCH)
    print('פורסם לבדיקות בלבד (האתר האמיתי לא השתנה)')
