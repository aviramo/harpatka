"""מפרסם את כל האתר לסביבת הבדיקות (https://test.harpatka.co.il, repo aviramo/harpatka-test).
מריצים בסוף שינוי: python tools/deploy-test.py   (אפשר גם --no-push לבנייה בלי דחיפה)
בונה עותק של האתר בתיקייה מחוץ ל-repo (~/harpatka-test-deploy), ומתאים אותו לבדיקות:
  - מזריק shared/env.js של הבדיקות (בקשות לסכמת test + תגית "סביבת בדיקות"), ומסיר Pixel ו-Google Analytics
  - noindex, robots.txt סוגר, CNAME של התת דומיין
  - דף הניהול של הבדיקות נוצר מ-admin/index.html (סכמת test בבקשות וב-realtime, פס "סביבת בדיקות"); אין יותר admin-test/
הקוד של האתר עצמו לא משתנה: ההתאמות נעשות רק בעותק."""
import os, re, shutil, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path.home() / 'harpatka-test-deploy'
REMOTE = 'https://github.com/aviramo/harpatka-test.git'
PUSH = '--no-push' not in sys.argv

DIRS = ['images', 'ads', 'biodanza', 'board', 'me', 'shared', 'register', 'privacy', 'v7', 'v8', 'v9']
FILES = ['index.html', 'sw.js', 'favicon.ico']


def run(*a, cwd=None):
    return subprocess.run(a, cwd=cwd or OUT, check=True, capture_output=True, text=True).stdout


def build_test_admin():
    """דף הניהול של הבדיקות, נגזר מ-admin/index.html ו-admin/admin.css: סכמת test בבקשות וב-realtime, פס "סביבת בדיקות", כותרת וקיזוז גובה."""
    src = ROOT / 'admin' / 'index.html'
    t = src.read_text(encoding='utf-8').replace('\r\n', '\n')
    css_src = src.parent / 'admin.css'
    css = css_src.read_text(encoding='utf-8').replace('\r\n', '\n') if css_src.exists() else None
    testbar_css = ("    :root { --envtop: 18px; }\n"
                   "    #testBadge { inset: auto; margin: 0; border: 0; position: fixed; top: 0; left: 0; right: 0; width: auto; height: 18px; padding: 0; overflow: hidden; background: #3F382F; color: #fff; font: 700 11px/18px Arial, sans-serif; text-align: center; pointer-events: none; }\n")
    testbar_div = '  <div id="testBadge" popover="manual">סביבת בדיקות · נתונים נפרדים מהאמיתיים</div>\n'

    def rep(old, new):
        nonlocal t
        if t.count(old) != 1:
            sys.exit('לא נמצא (או נמצא יותר מפעם אחת) בדף הניהול: ' + old[:70])
        t = t.replace(old, new)

    rep('<title>ניהול מפגשים · יוצאים להרפתקה</title>', '<title>בדיקות · ניהול מפגשים</title>')
    H_OLD, H_NEW = 'height: 100vh; height: 100dvh; margin-top: 0;', 'height: calc(100vh - 18px); height: calc(100dvh - 18px); margin-top: 18px;'
    if css is not None:
        if css.count(H_OLD) != 1:
            sys.exit('לא נמצא (או נמצא יותר מפעם אחת) ב-admin.css: ' + H_OLD)
        css = css.replace(H_OLD, H_NEW)
        rep('</head>', '  <style>\n' + testbar_css + '  </style>\n</head>')
    else:
        rep(H_OLD, H_NEW)
        rep('  <style>\n', '  <style>\n' + testbar_css)
    js = ('<script>(function(){var els=[document.getElementById("testBadge")];'
          'function up(){els.forEach(function(e){try{e.hidePopover();e.showPopover();}catch(x){}});}up();'
          'new MutationObserver(function(m){if(m.some(function(r){return r.target.nodeName==="DIALOG";}))up();}).observe(document.documentElement,{subtree:true,attributes:true,attributeFilter:["open"]});})();</script>')
    body_start = t.index('<body')
    end = t.index('>\n', body_start) + 2
    t = t[:end] + testbar_div + '  ' + js + '\n' + t[end:]   # הפס והסקריפט שמציג אותו מיד אחרי <body>: מופיע יחד עם הדף, לא אחרי שכל הדף נטען
    rep("schema: 'public'", "schema: 'test'")
    rep("DB.key) };", "DB.key), 'Accept-Profile': 'test', 'Content-Profile': 'test' };   // סביבת בדיקות: סכמה test")
    return t, css


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
_admin_html, _admin_css = build_test_admin()
(OUT / 'admin' / 'index.html').write_text(_admin_html, encoding='utf-8', newline='\n')
if _admin_css is not None:
    (OUT / 'admin' / 'admin.css').write_text(_admin_css, encoding='utf-8', newline='\n')
shutil.copy2(ROOT / 'tools' / 'test-site-env.js', OUT / 'shared' / 'env.js')

# כניסה עם גוגל לציבור: בפרודקשן כבויה (shared/config.js: googleLogin false). לפיתוח מחדש: קודם רק בבדיקות. True = בעותק של הבדיקות הכניסה פעילה (האמת לא משתנה)
GOOGLE_LOGIN_IN_TEST = True   # 30.10.26: הכניסה עם גוגל חוזרת, קודם בבדיקות בלבד
if GOOGLE_LOGIN_IN_TEST:
    _cfg = OUT / 'shared' / 'config.js'
    _cfg.write_text(_cfg.read_text(encoding='utf-8').replace('googleLogin: false', 'googleLogin: true', 1), encoding='utf-8')
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
    if inject_env:   # פס הבדיקות כתוב ב-HTML מיד אחרי <body>, כך שהוא מצויר יחד עם הדף (המקום שלו שמור כבר מה-<head>, env.js)
        badge = '<div id="testEnvBadge">סביבת בדיקות · נתונים נפרדים מהאמיתיים</div><script>window.__envBadge&&window.__envBadge()</script>'
        t = re.sub(r'(<body[^>]*>)', lambda m: m.group(1) + badge, t, count=1)
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
