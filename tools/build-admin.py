"""בונה את admin/index.html (סביבת האמת) מתוך admin-test/index.html (סביבת הבדיקות).
הסרת כל מה שמיוחד לבדיקות: סכמת test בבקשות וב-realtime, פס הבדיקות, כותרת הדף וקיזוז הגובה של הפס.
שימוש: python tools/build-admin.py   (אחר כך git add admin/index.html)"""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
src = (root / 'admin-test' / 'index.html').read_text(encoding='utf-8')
t = src.replace('\r\n', '\n')

def sub(pattern, repl, count=1, flags=0, must=True):
    global t
    t2, n = re.subn(pattern, repl, t, count=count, flags=flags)
    if must and n == 0:
        sys.exit('לא נמצא: ' + pattern[:60])
    t = t2

sub(r'<title>בדיקות · משתתפים</title>', '<title>משתתפים · יוצאים להרפתקה</title>')
sub(r'^    #testBar \{[^\n]*\n', '', flags=re.M)
sub(r'^  <div id="testBar"[^\n]*\n', '', flags=re.M)
sub(r"schema: 'test'", "schema: 'public'")
sub(r", 'Accept-Profile': 'test', 'Content-Profile': 'test' \};[^\n]*", ' };')
sub(r'height: calc\(100vh - 22px\); height: calc\(100dvh - 22px\); margin-top: 22px;', 'height: 100vh; height: 100dvh; margin-top: 0;')
assert "'test'" not in t and 'testBar' not in t, 'נשארו עקבות לבדיקות'
t = '<!-- נבנה אוטומטית מ-admin-test/index.html באמצעות tools/build-admin.py; לא לערוך ידנית -->\n' + t if not t.startswith('<!doctype') else t.replace('<!doctype html>', '<!doctype html>\n<!-- נבנה אוטומטית מ-admin-test/index.html באמצעות tools/build-admin.py; לא לערוך ידנית -->', 1)
(root / 'admin' / 'index.html').write_text(t, encoding='utf-8', newline='\n')
print('admin/index.html נבנה:', len(t), 'תווים')
