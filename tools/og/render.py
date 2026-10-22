"""מייצר תמונת שיתוף עם פרטי המפגש הקרוב: python tools/og/render.py YYYY-MM-DD HH:MM מקום out.jpg  (דורש playwright)"""
import sys, pathlib, datetime
from playwright.sync_api import sync_playwright
HERE = pathlib.Path(__file__).parent; ROOT = HERE.parent.parent
DAYS = ['שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת', 'ראשון']
def render(date, time, place, out):
    """בלי תאריך (date=None): אותו עיצוב בלי פרטי המפגש הקרוב"""
    if date:
        d = datetime.date.fromisoformat(date)
        when = f"יום {DAYS[d.weekday()]}, {d.day}.{d.month}"; details = ''; cls = ''
    else:
        when = time = place = ''; details = 'hidden style="display:none"'; cls = 'nodetails'
    html = (HERE / 'og.html').read_text(encoding='utf-8').replace('__BG__', (ROOT / 'images' / 'og-v3.jpg').as_uri()).replace('__WHEN__', when).replace('__TIME__', time).replace('__PLACE__', place).replace('__DETAILS__', details).replace('__CLS__', cls)
    tmp = HERE / '_og_tmp.html'; tmp.write_text(html, encoding='utf-8')
    with sync_playwright() as pw:
        b = pw.chromium.launch(); pg = b.new_page(viewport={'width': 1200, 'height': 1200})
        pg.goto(tmp.as_uri()); pg.evaluate('document.fonts.ready.then(() => true)'); pg.wait_for_timeout(600)
        pg.screenshot(path=str(out), type='jpeg', quality=86); b.close()
    tmp.unlink()
if __name__ == '__main__':
    render(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
