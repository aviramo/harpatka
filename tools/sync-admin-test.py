"""מסנכרן את סביבת הבדיקות (admin-test/index.html) מתוך סביבת האמת (admin/index.html).
העבודה נעשית ישירות על admin/index.html; אחרי כל שינוי מריצים: python tools/sync-admin-test.py
ואז git add admin-test/index.html. מוסיף לבדיקות רק את מה שמיוחד לה: סכמת test בבקשות וב-realtime,
פס "סביבת בדיקות", כותרת הדף וקיזוז הגובה של הפס. לא מעתיק נתונים. שינויי סכמה (SQL) מריצים בנפרד גם על test."""
import sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
t = (root / 'admin' / 'index.html').read_text(encoding='utf-8').replace('\r\n', '\n')

TESTBAR_CSS = ("    #testBar { position: fixed; top: 0; left: 0; right: 0; z-index: 9999; height: 22px; display: grid; "
               "place-items: center; background: #C96F52; color: #fff; font-size: 12px; font-weight: 800; "
               "letter-spacing: .02em; pointer-events: none; }\n")
TESTBAR_DIV = '  <div id="testBar" role="note">סביבת בדיקות · נתונים נפרדים מהאמיתיים</div>\n'


def rep(old, new):
    global t
    if t.count(old) != 1:
        sys.exit('לא נמצא (או נמצא יותר מפעם אחת): ' + old[:70])
    t = t.replace(old, new)


rep('<title>משתתפים · יוצאים להרפתקה</title>', '<title>בדיקות · משתתפים</title>')
rep('  <style>\n', '  <style>\n' + TESTBAR_CSS)
body_start = t.index('<body')
end = t.index('>\n', body_start) + 2
t = t[:end] + TESTBAR_DIV + t[end:]
rep("schema: 'public'", "schema: 'test'")
rep("DB.key) };", "DB.key), 'Accept-Profile': 'test', 'Content-Profile': 'test' };   // סביבת בדיקות: סכמה test")
rep('height: 100vh; height: 100dvh; margin-top: 0;',
    'height: calc(100vh - 22px); height: calc(100dvh - 22px); margin-top: 22px;')
(root / 'admin-test' / 'index.html').write_text(t, encoding='utf-8', newline='\n')
print('admin-test/index.html סונכרן:', len(t), 'תווים')
