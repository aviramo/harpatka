# מייצר תמונת שיתוף (og:image) 1200x630 בשפה הגרפית של ההזמנה -> images/og-v4.jpg (עד 300KB, מתאים לוואטסאפ)
import os, subprocess, pathlib, tempfile
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[2]
CHROME = next(p for p in [r"C:\Program Files\Google\Chrome\Application\chrome.exe", r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"] if os.path.exists(p))
IMG = (ROOT / "images").as_uri()
DANCERS = '<svg viewBox="0 0 48 52" style="width:100%;height:100%"><g stroke="#C96F52" stroke-width="2.2" stroke-linecap="round" fill="none"><path d="M15 21Q8 17 6 9"/><path d="M15 21Q21 18 24 12"/><path d="M34 22Q40 17 42 11"/><path d="M34 22Q29 19 27 14"/></g><g fill="#C96F52"><circle cx="15" cy="12" r="3.5"/><path d="M15 17C9 22 8 33 5 42L25 42C22 33 21 22 15 17Z"/></g><g fill="#9A9A75"><circle cx="34" cy="13" r="3.3"/><path d="M34 18C28.5 23 28 33 26 42L42 42C40 33 39.5 23 34 18Z"/></g></svg>'
HTML = f'''<!doctype html><html lang="he" dir="rtl"><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Rubik:wght@500;600;700&family=Assistant:wght@600;700&family=Amatic+SC:wght@700&display=swap" rel="stylesheet">
<style>
*{{margin:0;box-sizing:border-box}}html,body{{width:1200px;height:630px;overflow:hidden}}
body{{background:#F6EFE4;position:relative;font-family:Rubik,sans-serif;color:#3F382F}}
.frame{{position:absolute;inset:22px;border-radius:30px;padding:24px;background:repeating-linear-gradient(-45deg,#C96F52 0 30px,#FFFDF9 30px 52px,#9A9A75 52px 82px,#FFFDF9 82px 104px);box-shadow:0 8px 22px rgba(63,56,47,.12)}}
.paper{{position:relative;width:100%;height:100%;border-radius:16px;background:#FFFDF9;overflow:hidden}}
.c1{{position:absolute;right:-90px;top:-170px;width:420px;height:420px;border-radius:50%;background:#F4E8D8}}
.photo{{position:absolute;left:70px;top:46px;width:430px;height:430px;border-radius:58% 42% 55% 45% / 48% 58% 42% 52%;overflow:hidden;box-shadow:0 20px 44px rgba(63,56,47,.18)}}
.photo img{{width:100%;height:100%;object-fit:cover}}
.txt{{position:absolute;right:76px;top:34px;width:560px;text-align:right}}
.row{{display:flex;align-items:flex-start;justify-content:space-between}}
.hand{{font-family:"Amatic SC";font-weight:700;font-size:96px;line-height:1;color:#B85C40}}
.stamp{{width:78px;height:92px;background:#F3E3D1;border:7px dotted #FFFDF9;outline:2px solid #E6D3BC;outline-offset:-2px;transform:rotate(4deg);padding:8px;margin-top:4px}}
h1{{margin-top:14px;font-size:100px;line-height:1.02;font-weight:600;letter-spacing:-.01em}}
h1 em{{font-style:normal;color:#C96F52}}
.sub{{margin-top:22px;font-family:Assistant;font-weight:700;font-size:36px;line-height:1.3;color:#6b6254}}
.logo{{position:absolute;right:76px;bottom:34px;font-size:46px;font-weight:600}}
.logo b{{color:#C96F52;font-weight:700}}
</style><body>
<div class="frame"><div class="paper">
<div class="c1"></div>
<div class="photo"><img src="{IMG}/biodanza-hero-720.webp"></div>
<div class="txt">
  <div class="row"><div class="hand">הזמנה</div><div class="stamp">{DANCERS}</div></div>
  <h1>מפגש מסוג <em>אחר</em></h1>
  <div class="sub">תנועה, מוזיקה ואנשים חדשים בהרצליה</div>
</div>
<div class="logo">יוצאים <b>להרפתקה</b></div>
</div></div></body></html>'''
tmp = pathlib.Path(tempfile.mkdtemp()); f = tmp / "og.html"; f.write_text(HTML, encoding="utf-8"); png = tmp / "og.png"
subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--window-size=1200,630", "--virtual-time-budget=6000",
                f"--user-data-dir={tmp/'u'}", f"--screenshot={png}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
out = ROOT / "images" / "og-v4.jpg"
im = Image.open(png).convert("RGB")
for q in (90, 85, 80, 75, 70):
    im.save(out, "JPEG", quality=q, optimize=True, progressive=True)
    if out.stat().st_size <= 300 * 1024: break
print(im.size, out.stat().st_size // 1024, "KB, quality", q)
