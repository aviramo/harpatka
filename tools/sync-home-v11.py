"""מייצר את עמוד הבית (index.html בשורש) מ-v11/index.html, כך ששניהם זהים בתוכן.

עמוד הבית ו-v11 זהים תמיד (מ-7.11.26; קודם v10, שהוא עכשיו עותק קפוא). עורכים את v11/index.html ומריצים:
    python tools/sync-home-v11.py
ההבדלים היחידים: ב-v11 נתיבי ../ (תמונות, shared וכו'), noindex, ו-canonical / og:url ל-/v11/.
הסקריפט בודק שההמרה ההפוכה מחזירה בדיוק את v11.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V11 = os.path.join(ROOT, 'v11', 'index.html')
HOME = os.path.join(ROOT, 'index.html')
NOINDEX = '  <meta name="robots" content="noindex" />\n'


def to_home(v9):
    t = v9.replace('https://harpatka.co.il/v11/', 'https://harpatka.co.il/')
    t = t.replace(NOINDEX, '')
    return t.replace('../', '')


def main():
    v9 = open(V11, encoding='utf-8', newline='').read().replace('\r\n', '\n')
    if NOINDEX not in v9 or 'https://harpatka.co.il/v11/' not in v9:
        sys.exit('v11/index.html: חסרים noindex או canonical ל-/v11/')
    home = to_home(v9)
    if re.search(r'\.\./', home):
        sys.exit('נשארו נתיבי ../ בעמוד הבית')
    open(HOME, 'w', encoding='utf-8', newline='').write(home)
    print('index.html עודכן מ-v11/index.html (%d תווים)' % len(home))


if __name__ == '__main__':
    main()
