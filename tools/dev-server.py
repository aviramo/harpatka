"""שרת פיתוח מקומי: python tools/dev-server.py [פורט]   (ברירת מחדל 8080)
מגיש את האתר מהתיקייה הנוכחית, ובכל רענון דף הניהול (/admin/) נבנה מחדש מ-admin/ בגרסת הבדיקות
(סכמת test, פס "סביבת בדיקות"), בדיוק כמו tools/deploy-test.py. שינוי בקוד = רענון בדפדפן, בלי פרסום.
נגיש גם מהטלפון באותה רשת: http://<כתובת המחשב>:<פורט>/admin/
כל עמודי האתר (עמוד הבית, v10, אזור אישי ועוד) מוגשים בגרסת הבדיקות, כמו test.harpatka.co.il: בקשות לסכמת test
(shared/env.js), בלי Pixel ו-Google Analytics, וכניסה עם גוגל פעילה (כמו ב-GOOGLE_LOGIN_IN_TEST). לא נכתב דבר לדיסק."""
import ast, http.server, mimetypes, pathlib, re, socket, sys, urllib.parse

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

    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        if p == '/admin':   # בלי / בסוף הנתיבים היחסיים (admin.css) נשברים: מפנים ל-/admin/
            self.send_response(301); self.send_header('Location', '/admin/'); self.end_headers(); return
        if p in ('/admin', '/admin/', '/admin/index.html'):
            html, css = build_test_admin('admin')
            return self._send(html, 'text/html; charset=utf-8')
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
