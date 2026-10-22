"""
מעדכן את תמונת השיתוף של עמוד הבית (index.html ו-v7/index.html) לפי המפגש הקרוב בבסיס הנתונים.
רץ אוטומטית כל לילה ב-GitHub Actions (.github/workflows/og-image.yml) ואפשר גם ידנית: python tools/og/update.py
- יש מפגש קרוב: images/og-meeting-<תאריך>-<hash>.jpg (שם חדש בכל שינוי, בגלל cache של וואטסאפ ופייסבוק)
- אין מפגש קרוב: images/og-general-<hash>.jpg (אותו עיצוב בלי פרטי המפגש)
"""
import datetime, hashlib, json, pathlib, re, sys, urllib.request, zoneinfo
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from render import render
ROOT = pathlib.Path(__file__).parent.parent.parent
URL = 'https://ezakarwqstnldqixgreb.supabase.co'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6YWthcndxc3RubGRxaXhncmViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMTA3MzIsImV4cCI6MjEwNjc4NjczMn0.Bg0eFBC4zKjyJc5kBw3wLgSP-PkxLFVv3o7-4YUdq4c'   # מפתח ציבורי (anon)
PLACE = 'הרצליה'
PAGES = ['index.html', 'v7/index.html']
DEFAULT = 'og-v3.jpg'

def next_meeting():
    try: now = datetime.datetime.now(zoneinfo.ZoneInfo('Asia/Jerusalem'))
    except Exception: now = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=3)   # בלי מאגר אזורי זמן (חלונות)
    today = now.date().isoformat()
    req = urllib.request.Request(f'{URL}/rest/v1/harpatka_meetings?select=meeting_date,meeting_time&meeting_date=gte.{today}&order=meeting_date.asc,meeting_time.asc&limit=1',
                                 headers={'apikey': KEY, 'Authorization': 'Bearer ' + KEY})
    rows = json.load(urllib.request.urlopen(req, timeout=30))
    return rows[0] if rows else None

def main():
    m = None if '--none' in sys.argv else next_meeting()
    images = ROOT / 'images'
    if m:
        date, time = m['meeting_date'], m['meeting_time'][:5]
        tpl = (pathlib.Path(__file__).parent / 'og.html').read_bytes() + (images / DEFAULT).read_bytes()[:4096]
        h = hashlib.sha1((date + time + PLACE).encode() + tpl).hexdigest()[:6]
        name = f"og-meeting-{date.replace('-', '')}-{h}.jpg"
        if not (images / name).exists():
            render(date, time, PLACE, images / name)
    else:   # אין מפגש קרוב: אותה תמונה בלי פרטי המפגש
        tpl = (pathlib.Path(__file__).parent / 'og.html').read_bytes()
        name = f"og-general-{hashlib.sha1(tpl).hexdigest()[:6]}.jpg"
        if not (images / name).exists():
            render(None, '', '', images / name)
    for old in list(images.glob('og-meeting-*.jpg')) + list(images.glob('og-general-*.jpg')):
        if old.name != name: old.unlink()
    changed = False
    for page in PAGES:
        p = ROOT / page
        t = p.read_bytes().decode('utf-8')
        n = re.sub(r'(<meta (?:property="og:image"|name="twitter:image") content="https://harpatka\.co\.il/images/)[^"]+(")', r'\g<1>' + name + r'\g<2>', t)
        if n != t: p.write_bytes(n.encode('utf-8')); changed = True
    print(('meeting ' + m['meeting_date'] + ' ' + m['meeting_time'][:5] if m else 'no upcoming meeting') + ' -> ' + name + (' (pages updated)' if changed else ' (no change)'))

if __name__ == '__main__':
    main()
