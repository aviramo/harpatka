"""שרת פיתוח מקומי: python tools/dev-server.py [פורט]   (ברירת מחדל 8080)
מגיש את האתר מהתיקייה הנוכחית, ובכל רענון דף הניהול (/admin/) נבנה מחדש מ-admin/ בגרסת הבדיקות
(סכמת test, פס "סביבת בדיקות"), בדיוק כמו tools/deploy-test.py. שינוי בקוד = רענון בדפדפן, בלי פרסום.
נגיש גם מהטלפון באותה רשת: http://<כתובת המחשב>:<פורט>/admin/
כל עמודי האתר (עמוד הבית, v10, אזור אישי ועוד) מוגשים בגרסת הבדיקות, כמו test.harpatka.co.il: בקשות לסכמת test
(shared/env.js), בלי Pixel ו-Google Analytics, וכניסה עם גוגל פעילה (כמו ב-GOOGLE_LOGIN_IN_TEST).
כניסה לדף הניהול: מתחברים עם גוגל פעם אחת בלבד. השרת זוכר את החיבור בקובץ ~/.harpatka-dev-session.json (בתיקיית הבית, מחוץ ל-repo ולא מוגש),
וכל פתיחה של /admin/ (בכל כתובת: localhost, כתובת הרשת מהטלפון, אחרי ניקוי דפדפן) נכנסת אוטומטית בלי גוגל. הרענון של החיבור נשמר אצלו
(כמו שדף הניהול מרענן אותו), יציאה מהחשבון בדף הניהול מוחקת אותו, ואז הכניסה הבאה היא עם גוגל שוב. החיבור נמסר רק למחשב הזה ולמכשירים ברשת הביתית
(כתובת פרטית), ורק כשהכתובת בדפדפן היא localhost או כתובת IP (נגד DNS rebinding). אין שימוש במפתחות שירות ואין כתיבה לדיסק מלבד הקובץ הזה."""
import ast, http.server, ipaddress, json, mimetypes, os, pathlib, re, socket, sys, urllib.parse

SCRIPT = re.compile(r'<script\b[^>]*>.*?</script>', re.S | re.I)
NOSCRIPT = re.compile(r'<noscript>.*?</noscript>', re.S | re.I)

ROOT = pathlib.Path(__file__).resolve().parent.parent
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

# build_test_admin נלקחת מ-deploy-test.py (בלי להריץ אותו)
_src = (ROOT / 'tools' / 'deploy-test.py').read_text(encoding='utf-8')
_fn = next(n for n in ast.parse(_src).body if isinstance(n, ast.FunctionDef) and n.name == 'build_test_admin')
_ns = {'ROOT': ROOT, 'sys': sys}
exec(compile(ast.Module(body=[_fn], type_ignores=[]), 'deploy-test.py', 'exec'), _ns)
build_test_admin = _ns['build_test_admin']


def adapt_html(t):
    """כמו adapt ב-tools/deploy-test.py: בלי מעקב, env.js של הבדיקות, תגית ופס בדיקות."""
    def tracking(m):
        x = m.group(0)
        return 'googletagmanager.com' in x or 'G-KPSZRGZQRK' in x or 'connect.facebook.net' in x
    t = SCRIPT.sub(lambda m: '' if tracking(m) else m.group(0), t)
    t = NOSCRIPT.sub(lambda m: '' if 'facebook.com/tr' in m.group(0) else m.group(0), t)
    t = re.sub(r'<link rel="canonical"[^>]*>', '', t)
    t = re.sub(r'(<head[^>]*>)', lambda m: m.group(1) + '<script src="/shared/env.js"></script><meta name="robots" content="noindex, nofollow">', t, count=1)
    badge = '<div id="testEnvBadge">סביבת בדיקות · נתונים נפרדים מהאמיתיים</div><script>window.__envBadge&&window.__envBadge()</script>'
    return re.sub(r'(<body[^>]*>)', lambda m: m.group(1) + badge, t, count=1)

# ---- כניסה אוטומטית לדף הניהול (חיבור גוגל שנזכר, ראו את התיאור למעלה) ----
SESSION_FILE = pathlib.Path(os.environ.get('HARPATKA_DEV_SESSION_FILE') or (pathlib.Path.home() / '.harpatka-dev-session.json'))   # הגדרת סביבה: קובץ אחר (לבדיקות)
NO_SESSION = bool(os.environ.get('HARPATKA_DEV_NOSESSION'))   # הגדרת סביבה: בלי הזרקת החיבור (לבדיקות אוטומטיות עם חיבור מדומה, כדי שלא ידרסו את החיבור האמיתי)


def real_token(tok):
    """חיבור אמיתי של Supabase: JWT עם חתימה באורך רגיל. חיבור מדומה (בדיקות אוטומטיות) לא נשמר ולא מוזרק."""
    try:
        h, p, s = tok.split('.')
        return len(s) >= 20 and len(h) >= 10
    except (AttributeError, ValueError):
        return False
SESSION_KEY = 'harpatka_admin_session_v2'
SESSION_JS = """<script>(function(){var K='%s';
function exp(s){try{return JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).exp||0}catch(e){return 0}}
function call(m,b){try{var r=new XMLHttpRequest();r.open(m,'/__dev/session',true);r.setRequestHeader('X-Dev','1');r.send(b||null)}catch(e){}}
var set=Storage.prototype.setItem,rem=Storage.prototype.removeItem;
Storage.prototype.setItem=function(k,v){set.apply(this,arguments);if(k===K)call('POST',v)};
Storage.prototype.removeItem=function(k){rem.apply(this,arguments);if(k===K)call('DELETE')};
/* הדבקת חיבור בלי קונסולה: http://localhost:8080/admin/#devsession=<הדבקה של מה שהועתק מ-localStorage.harpatka_admin_session_v2> */
if(location.hash.indexOf('#devsession=')===0){try{var raw=location.hash.slice(12),o;try{o=JSON.parse(decodeURIComponent(raw))}catch(e){o=JSON.parse(raw)}
if(o&&typeof o.access_token==='string'&&typeof o.refresh_token==='string')localStorage.setItem(K,JSON.stringify({access_token:o.access_token,refresh_token:o.refresh_token}))}catch(e){}
try{history.replaceState(null,'',location.pathname+location.search)}catch(e){}}
var cur=null,srv=null;
function real(s){try{var p=s.access_token.split('.');return p.length===3&&p[2].length>=20&&p[0].length>=10}catch(e){return false}}
try{cur=JSON.parse(localStorage.getItem(K)||'null')}catch(e){cur=null}
if(cur&&!real(cur)){rem.call(localStorage,K);cur=null}   /* חיבור מדומה או פגום בדפדפן: מנקים בלי למחוק את החיבור השמור בשרת */
try{var x=new XMLHttpRequest();x.open('GET','/__dev/session',false);x.setRequestHeader('X-Dev','1');x.send();if(x.status===200)srv=JSON.parse(x.responseText)}catch(e){}
try{if(srv&&srv.access_token&&(!cur||!cur.access_token||exp(srv)>exp(cur)))localStorage.setItem(K,JSON.stringify(srv));
else if(cur&&cur.access_token&&cur.refresh_token&&(!srv||exp(cur)>exp(srv)))call('POST',JSON.stringify(cur))}catch(e){}
})();</script>""" % SESSION_KEY


def with_session(html):
    """מוסיף ל-<head> של דף הניהול את הסקריפט שמכניס את החיבור השמור לפני שהדף נטען."""
    if NO_SESSION:
        return html
    return re.sub(r'(<head[^>]*>)', lambda m: m.group(1) + SESSION_JS, html, count=1)


class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def _send(self, body, ctype):
        b = body.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _dev_ok(self):
        """החיבור השמור נמסר רק מכתובת פרטית (המחשב הזה או הרשת הביתית), ורק כשהכתובת בדפדפן היא localhost או IP (לא שם דומיין: נגד DNS rebinding), ועם הכותרת X-Dev."""
        try:
            ip = ipaddress.ip_address(self.client_address[0].split('%')[0])
        except ValueError:
            return False
        if not (ip.is_loopback or ip.is_private):
            return False
        host = (self.headers.get('Host') or '').strip()
        host = host[1:host.index(']')] if host.startswith('[') else host.rsplit(':', 1)[0] if ':' in host else host
        if host != 'localhost':
            try:
                ipaddress.ip_address(host)
            except ValueError:
                return False
        return self.headers.get('X-Dev') == '1'

    def _empty(self, code):
        self.send_response(code); self.send_header('Content-Length', '0'); self.end_headers()

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path != '/__dev/session' or not self._dev_ok():
            return self._empty(403)
        try:
            n = int(self.headers.get('Content-Length') or 0)
            d = json.loads(self.rfile.read(min(n, 8192)).decode('utf-8'))
            if not (isinstance(d.get('access_token'), str) and isinstance(d.get('refresh_token'), str) and d['refresh_token'] and real_token(d['access_token'])):
                return self._empty(400)   # גם חיבור מדומה (חתימה קצרה) נדחה, כדי שבדיקות אוטומטיות לא ידרסו את החיבור האמיתי
            SESSION_FILE.write_text(json.dumps({'access_token': d['access_token'], 'refresh_token': d['refresh_token']}), encoding='utf-8')
            return self._empty(204)
        except Exception:
            return self._empty(400)

    def do_DELETE(self):
        if urllib.parse.urlparse(self.path).path != '/__dev/session' or not self._dev_ok():
            return self._empty(403)
        try:
            SESSION_FILE.unlink()
        except FileNotFoundError:
            pass
        return self._empty(204)

    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        if p == '/__dev/session':
            if not self._dev_ok():
                return self._empty(403)
            try:
                txt = SESSION_FILE.read_text(encoding='utf-8')
                if not real_token(json.loads(txt).get('access_token')):   # קובץ מדומה או פגום: נמחק ולא נמסר
                    SESSION_FILE.unlink(); return self._empty(404)
                return self._send(txt, 'application/json')
            except (FileNotFoundError, ValueError):
                return self._empty(404)
        if p == '/admin':   # בלי / בסוף הנתיבים היחסיים (admin.css) נשברים: מפנים ל-/admin/
            self.send_response(301); self.send_header('Location', '/admin/'); self.end_headers(); return
        if p in ('/admin', '/admin/', '/admin/index.html'):
            html, css = build_test_admin('admin')
            return self._send(with_session(html), 'text/html; charset=utf-8')
        if p == '/admin/admin.css':
            html, css = build_test_admin('admin')
            return self._send(css, 'text/css; charset=utf-8')
        if p == '/shared/env.js':
            return self._send((ROOT / 'tools' / 'test-site-env.js').read_text(encoding='utf-8'), 'application/javascript; charset=utf-8')
        if p == '/shared/config.js':
            t = (ROOT / 'shared' / 'config.js').read_text(encoding='utf-8').replace('googleLogin: false', 'googleLogin: true', 1)
            return self._send(t, 'application/javascript; charset=utf-8')
        f = ROOT / p.lstrip('/')
        if f.is_dir() and (f / 'index.html').exists():
            f = f / 'index.html'
        if f.is_file() and f.suffix == '.html':
            return self._send(adapt_html(f.read_text(encoding='utf-8')), 'text/html; charset=utf-8')
        return super().do_GET()

    def translate_path(self, path):
        return str(ROOT / urllib.parse.urlparse(path).path.lstrip('/'))


def lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'


if __name__ == '__main__':
    srv = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), H)
    print(f'שרת פיתוח: http://localhost:{PORT}/admin/   (ברשת: http://{lan_ip()}:{PORT}/admin/)')
    srv.serve_forever()
