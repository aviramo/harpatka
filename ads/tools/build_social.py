# מייצר תמונת קאבר (1640x624) ותמונת פרופיל (1080x1080) לדף הפייסבוק -> ads/social/
# הרצה: python ads/tools/build_social.py   (דורש Chrome)
import os, subprocess, pathlib, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
CHROME = next(p for p in [r"C:\Program Files\Google\Chrome\Application\chrome.exe", r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"] if os.path.exists(p))
IMG = (ROOT / "images").as_uri()
OUT = ROOT / "ads" / "social"; OUT.mkdir(parents=True, exist_ok=True)

DANCERS = lambda a, b: f'<svg viewBox="0 0 48 52" style="width:100%;height:100%"><g stroke="{a}" stroke-width="2.2" stroke-linecap="round" fill="none"><path d="M15 21Q8 17 6 9"/><path d="M15 21Q21 18 24 12"/><path d="M34 22Q40 17 42 11"/><path d="M34 22Q29 19 27 14"/></g><g fill="{a}"><circle cx="15" cy="12" r="3.5"/><path d="M15 17C9 22 8 33 5 42L25 42C22 33 21 22 15 17Z"/></g><g fill="{b}"><circle cx="34" cy="13" r="3.3"/><path d="M34 18C28.5 23 28 33 26 42L42 42C40 33 39.5 23 34 18Z"/></g></svg>'

PROFILE = f'''<!doctype html><html lang="he" dir="rtl"><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600&family=Rubik:wght@600&display=swap" rel="stylesheet">
<style>
*{{margin:0;box-sizing:border-box}}html,body{{width:1080px;height:1080px;overflow:hidden}}
body{{background:#F6EFE4;position:relative}}
img{{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:50% 45%}}
/* כיתוב עליון — בתוך אזור החיתוך העגול של פייסבוק */
.cap{{position:absolute;left:50%;top:170px;transform:translateX(-50%);padding:16px 52px 20px;border-radius:999px;background:rgba(255,253,249,.93);
 font-family:Fredoka,Rubik,sans-serif;font-weight:600;font-size:78px;line-height:1;color:#3F382F;white-space:nowrap;box-shadow:0 8px 24px rgba(63,56,47,.16)}}
.cap em{{font-style:normal;color:#C96F52}}
</style><body>
<img src="{IMG}/biodanza-hero.webp">
</body></html>'''

COVER_T = f'''<!doctype html><html lang="he" dir="rtl"><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Rubik:wght@500;600;700&family=Amatic+SC:wght@700&display=swap" rel="stylesheet">
<style>
*{{margin:0;box-sizing:border-box}}html,body{{width:1640px;height:624px;overflow:hidden}}
body{{background:#F6EFE4;position:relative;font-family:Rubik,sans-serif;color:#3F382F}}
/* מעטפת דואר: מסגרת פסים סביב כל הקאבר, בלי תמונה */
.frame{{position:absolute;inset:20px;border-radius:30px;padding:22px;background:repeating-linear-gradient(-45deg,#C96F52 0 30px,#FFFDF9 30px 52px,#9A9A75 52px 82px,#FFFDF9 82px 104px);box-shadow:0 8px 22px rgba(63,56,47,.10)}}
.paper{{position:relative;width:100%;height:100%;border-radius:16px;background:#FFFDF9;overflow:hidden}}
.c1{{position:absolute;left:-110px;top:-200px;width:540px;height:540px;border-radius:50%;background:#F1E4D3}}
.c2{{position:absolute;right:-70px;bottom:-110px;width:380px;height:460px;border-radius:190px 190px 0 0;background:rgba(154,154,117,.28)}}
.c3{{position:absolute;left:250px;bottom:60px;width:130px;height:130px;border-radius:50%;background:#E9B8A4;opacity:.75}}
.c4{{position:absolute;right:300px;top:110px;width:56px;height:56px;border-radius:50%;background:#C98D86;opacity:.7}}
.stamp{{position:absolute;left:330px;top:50px;width:96px;height:114px;background:#F3E3D1;border:9px dotted #FFFDF9;outline:2px solid #E6D3BC;outline-offset:-2px;transform:rotate(4deg);padding:10px}}
.hand{{position:absolute;right:340px;top:40px;font-family:"Amatic SC";font-weight:700;font-size:118px;line-height:1;color:#B85C40}}
.txt{{position:absolute;left:250px;width:700px;top:0;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding-bottom:30px}}
h1{{font-size:150px;line-height:.98;font-weight:600;letter-spacing:-.01em;color:#C96F52}}
.sub{{margin-top:10px;font-size:72px;line-height:1.1;font-weight:500;color:#3F382F}}
</style><body>
<div class="frame"><div class="paper">
<div class="c1"></div><div class="c2"></div><div class="c3"></div><div class="c4"></div>
<div class="txt"><h1>ביודנסה</h1><div class="sub">@@SUB@@</div></div>
</div></div></body></html>'''

def cover(sub):
    return COVER_T.replace("@@SUB@@", sub)

def shot(html, w, h, name):
    tmp = pathlib.Path(tempfile.mkdtemp()); f = tmp / "p.html"; f.write_text(html, encoding="utf-8")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--window-size={w},{h}", "--virtual-time-budget=6000",
                    f"--user-data-dir={tmp/'u'}", f"--screenshot={OUT/name}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("ok", name)

if __name__ == "__main__":
    shot(PROFILE, 1080, 1080, "facebook-profile.png")
    shot(cover("מפגש מסוג אחר"), 1640, 624, "facebook-cover.png")
