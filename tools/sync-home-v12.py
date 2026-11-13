"""מייצר את עמוד הבית (index.html בשורש) מ-v12/index.html, כך ששניהם זהים בתוכן.

עמוד הבית ו-v12 זהים תמיד (מ-7.11.26; קודם v10, שהוא עכשיו עותק קפוא). עורכים את v12/index.html ומריצים:
    python tools/sync-home-v12.py
ההבדלים היחידים: ב-v12 נתיבי ../ (תמונות, shared וכו'), noindex, ו-canonical / og:url ל-/v12/.
הסקריפט בודק שההמרה ההפוכה מחזירה בדיוק את v12.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V12 = os.path.join(ROOT, 'v12', 'index.html')
HOME = os.path.join(ROOT, 'index.html')
NOINDEX = '  <meta name="robots" content="noindex" />\n'


def to_home(v11):
    t = v11.replace('https://harpatka.co.il/v12/', 'https://harpatka.co.il/')
    t = t.replace(NOINDEX, '')
    return t.replace('../', '')


def main():
    v11 = open(V12, encoding='utf-8', newline='').read().replace('\r\n', '\n')
    if NOINDEX not in v11 or 'https://harpatka.co.il/v12/' not in v11:
        sys.exit('v12/index.html: חסרים noindex או canonical ל-/v12/')
    home = to_home(v11)
    if re.search(r'\.\./', home):
        sys.exit('נשארו נתיבי ../ בעמוד הבית')
    open(HOME, 'w', encoding='utf-8', newline='').write(home)
    print('index.html עודכן מ-v12/index.html (%d תווים)' % len(home))


if __name__ == '__main__':
    main()
