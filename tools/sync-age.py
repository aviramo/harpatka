"""מעדכן את טווח הגילאים בטקסטים הקבועים בקוד לפי המקור היחיד shared/age.js (AGE_MIN, AGE_MAX).
הרצה אחרי כל שינוי של הגילאים: python tools/sync-age.py
מה מתעדכן: כל אלמנט עם data-age (הטקסט ההתחלתי, לפני JavaScript), וגם ביטויי גיל בטקסט שנקרא בלי JavaScript:
כותרת הדף, התיאור לגוגל ולשיתוף (meta, og, twitter, JSON-LD) וטקסט חלופי לתמונות: "גילאי 40–50", "לגילאי 40 עד 50", "aged 40 to 50".
ארכיונים (v1 עד v8) וסרטונים לא משתנים (הסצנות של הסרטונים קוראות מ-age.js ברינדור הבא)."""
import re, sys, pathlib
sys.stdout.reconfigure(encoding='utf-8')
ROOT = pathlib.Path(__file__).resolve().parent.parent
src = (ROOT / 'shared' / 'age.js').read_text(encoding='utf-8')
MIN = int(re.search(r'AGE_MIN\s*=\s*(\d+)', src).group(1))
MAX = int(re.search(r'AGE_MAX\s*=\s*(\d+)', src).group(1))
TEXT = {'range': f'{MIN}–{MAX}', 'to': f'{MIN} עד {MAX}', 'en': f'{MIN} to {MAX}', 'min': str(MIN), 'max': str(MAX)}

FILES = ['index.html', 'v9/index.html', 'privacy/index.html', 'biodanza/index.html', 'ads/index.html', 'register/index.html', 'me/index.html', 'board/index.html']
WORDS = r'(גילאי|בגילאי|לגילאי|בגילי|לגילי|גילי)'
changed = 0
for rel in FILES:
    p = ROOT / rel
    if not p.exists():
        continue
    t0 = t = p.read_text(encoding='utf-8')
    t = re.sub(r'(<[^>]*\sdata-age="(\w+)"[^>]*>)[^<]*(<)', lambda m: m.group(1) + TEXT.get(m.group(2), TEXT['range']) + m.group(3), t)
    t = re.sub(WORDS + r'(\s+)\d{2}–\d{2}', lambda m: m.group(1) + m.group(2) + TEXT['range'], t)
    t = re.sub(WORDS + r'(\s+)\d{2} עד \d{2}', lambda m: m.group(1) + m.group(2) + TEXT['to'], t)
    t = re.sub(r'aged \d{2} to \d{2}', 'aged ' + TEXT['en'], t)
    if t != t0:
        p.write_text(t, encoding='utf-8', newline='')
        changed += 1
        print('עודכן:', rel)
print(f'טווח: {MIN}–{MAX}. קבצים שעודכנו: {changed}')
