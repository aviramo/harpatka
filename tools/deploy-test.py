"""מפרסם את כל האתר לסביבת הבדיקות (https://test.harpatka.co.il, repo aviramo/harpatka-test).
מריצים בסוף שינוי: python tools/deploy-test.py   (אפשר גם --no-push לבנייה בלי דחיפה)
בונה עותק של האתר בתיקייה מחוץ ל-repo (~/harpatka-test-deploy), ומתאים אותו לבדיקות:
  - מזריק shared/env.js של הבדיקות (בקשות לסכמת test + תגית "סביבת בדיקות"), ומסיר Pixel ו-Google Analytics
  - noindex, robots.txt סוגר, CNAME של התת דומיין
  - דף הניהול נלקח מ-admin-test/index.html (נוצר ע"י tools/sync-admin-test.py)
הקוד של האתר עצמו לא משתנה: ההתאמות נעשות רק בעותק."""
import os, re, shutil, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path.home() / 'harpatka-test-deploy'
REMOTE = 'https://github.com/aviramo/harpatka-test.git'
PUSH = '--no-push' not in sys.argv

DIRS = ['images', 'ads', 'biodanza', 'board', 'me', 'shared', 'register', 'v7']
FILES = ['index.html', 'sw.js', 'favicon.ico']


def run(*a, cwd=None):
    return subprocess.run(a, cwd=cwd or OUT, check=True, capture_output=True, text=True).stdout


# 1. תיקיית עבודה (clone / init)
if not (OUT / '.git').exists():
    OUT.mkdir(parents=True, exist_ok=True)
    run('git', 'init', '-b', 'main', cwd=OUT)
    run('git', 'remote', 'add', 'origin', REMOTE, cwd=OUT)
for p in OUT.iterdir():
    if p.name == '.git':
        continue
    shutil.rmtree(p) if p.is_dir() else p.unlink()

# 2. העתקה
for d in DIRS:
    shutil.copytree(ROOT / d, OUT / d, ignore=shutil.ignore_patterns('*.sql', '.DS_Store'))
for f in FILES:
    shutil.copy2(ROOT / f, OUT / f)
(OUT / 'admin').mkdir()
shutil.copy2(ROOT / 'admin-test' / 'index.html', OUT / 'admin' / 'index.html')
shutil.copy2(ROOT / 'tools' / 'test-site-env.js', OUT / 'shared' / 'env.js')
(OUT / 'CNAME').write_text('test.harpatka.co.il\n', encoding='utf-8')
(OUT / '.nojekyll').write_text('', encoding='utf-8')
(OUT / 'robots.txt').write_text('User-agent: *\nDisallow: /\n', encoding='utf-8')

# 3. התאמת עמודי HTML
SCRIPT = re.compile(r'<script\b[^>]*>.*?</script>', re.S | re.I)
NOSCRIPT = re.compile(r'<noscript>.*?</noscript>', re.S | re.I)


def is_tracking_script(m):
    s = m.group(0)
    return 'googletagmanager.com' in s or 'G-KPSZRGZQRK' in s or 'connect.facebook.net' in s


def adapt(path, inject_env):
    t = path.read_text(encoding='utf-8')
    t = SCRIPT.sub(lambda m: '' if is_tracking_script(m) else m.group(0), t)
    t = NOSCRIPT.sub(lambda m: '' if 'facebook.com/tr' in m.group(0) else m.group(0), t)
    t = re.sub(r'<link rel="canonical"[^>]*>', '', t)
    add = ('<script src="/shared/env.js"></script>' if inject_env else '') + '<meta name="robots" content="noindex, nofollow">'
    t, n = re.subn(r'(<head[^>]*>)', lambda m: m.group(1) + add, t, count=1)
    if not n:
        sys.exit('אין <head> ב-' + str(path))
    path.write_text(t, encoding='utf-8', newline='\n')


for p in OUT.rglob('*.html'):
    rel = p.relative_to(OUT).as_posix()
    adapt(p, inject_env=(rel != 'admin/index.html'))

# 4. בדיקה שלא נשאר מעקב
bad = [p.relative_to(OUT).as_posix() for p in OUT.rglob('*.html')
       if re.search(r'googletagmanager|fbevents|429806621602468|G-KPSZRGZQRK', p.read_text(encoding='utf-8'))]
if bad:
    sys.exit('נשאר קוד מעקב ב: ' + ', '.join(bad))
print('נבנה:', sum(1 for _ in OUT.rglob('*') if _.is_file()), 'קבצים ב-', OUT)

# 5. דחיפה
if PUSH:
    run('git', 'add', '-A')
    if run('git', 'status', '--porcelain').strip():
        run('git', 'commit', '-m', 'deploy test')
        print(run('git', 'push', '-u', 'origin', 'main'))
        print('נדחף ל-test.harpatka.co.il')
    else:
        print('אין שינוי')
