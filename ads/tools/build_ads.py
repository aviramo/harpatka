# מייצר תמונת מודעה (1080x1350, יחס 4:5) לכל שורה ב-ads/sentences.txt
# הרצה:  python ads/tools/build_ads.py   (דורש Chrome ו-Pillow)
import os, sys, json, subprocess, html, tempfile, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
CHROME = next(p for p in [r"C:\Program Files\Google\Chrome\Application\chrome.exe", r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"] if os.path.exists(p))
W, H = 1080, 1350
IMG = (ROOT / "images").as_uri()
PHOTOS = ["dance-foot.webp", "fingertips.webp", "hands-heart-wide.webp"]
DANCERS = '<svg viewBox="0 0 48 52" fill="currentColor" style="width:100%;height:100%"><g stroke="currentColor" stroke-width="1.8" stroke-linecap="round" fill="none"><path d="M15 21Q8 17 6 9"/><path d="M15 21Q21 18 24 12"/><path d="M34 22Q40 17 42 11"/><path d="M34 22Q29 19 27 14"/></g><circle cx="15" cy="12" r="3.4"/><path d="M15 17C9 22 8 33 5 42L25 42C22 33 21 22 15 17Z"/><circle cx="34" cy="13" r="3.2" fill="#9A9A75"/><path d="M34 18C28.5 23 28 33 26 42L42 42C40 33 39.5 23 34 18Z" fill="#9A9A75"/></svg>'

# עיצובים: bg, צבע טקסט, צבע הדגשה, צבע לוגו, תמונה/מסגרת
STYLES = [
  dict(k="cream",  bg="#F6EFE4", fg="#3F382F", acc="#C96F52", deco="blob"),
  dict(k="terra",  bg="#C96F52", fg="#FFFDF9", acc="#F6EFE4", deco="none"),
  dict(k="sand",   bg="#E8D5BE", fg="#3F382F", acc="#C96F52", deco="blob"),
  dict(k="olive",  bg="#686A48", fg="#FFFDF9", acc="#E8D5BE", deco="none"),
  dict(k="mail",   bg="#F6EFE4", fg="#3F382F", acc="#C96F52", deco="mail"),
  dict(k="dusty",  bg="linear-gradient(160deg,#E7B7A6,#C98D86)", fg="#3F382F", acc="#FFFDF9", deco="none"),
]

def page(text, i):
    s = STYLES[i % len(STYLES)]
    photo = PHOTOS[i % len(PHOTOS)]
    deco = s["deco"]
    deco_html = ""
    top_pad = 120
    if deco == "blob":
        deco_html = f'<div class="blob"><img src="{IMG}/{photo}"></div>'
        top_pad = 120
    mail = ""
    if deco == "mail":
        mail = '<div class="frame"></div>'
    stamp = f'<div class="stamp" style="color:{s["acc"]}">{DANCERS}</div>' if deco == "mail" else ""
    return f'''<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Rubik:wght@500;600;700&family=Assistant:wght@600;700&family=Amatic+SC:wght@700&display=swap" rel="stylesheet">
<style>
*{{box-sizing:border-box;margin:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{background:{s["bg"]};color:{s["fg"]};font-family:Rubik,Assistant,sans-serif;position:relative}}
.blob{{position:absolute;top:110px;left:50%;transform:translateX(-50%);width:520px;height:520px;border-radius:58% 42% 55% 45% / 48% 58% 42% 52%;overflow:hidden;box-shadow:0 24px 50px rgba(63,56,47,.15)}}
.blob img{{width:100%;height:100%;object-fit:cover}}
.frame{{position:absolute;inset:44px;border-radius:30px;padding:16px;background:repeating-linear-gradient(-45deg,#C96F52 0 30px,#FFFDF9 30px 52px,#9A9A75 52px 82px,#FFFDF9 82px 104px)}}
.frame::after{{content:"";position:absolute;inset:16px;background:#FFFDF9;border-radius:18px}}
.stamp{{position:absolute;top:96px;left:96px;width:120px;height:140px;background:#F3E3D1;border:9px dotted #FFFDF9;outline:2px solid #E6D3BC;outline-offset:-2px;transform:rotate(4deg);padding:12px;color:#C96F52}}
.stamp svg{{color:#C96F52}}
.hand{{position:absolute;top:96px;right:110px;font-family:"Amatic SC";font-weight:700;font-size:130px;line-height:1;color:{s["acc"]}}}
.txt{{position:absolute;left:90px;right:90px;display:flex;align-items:center;justify-content:center;text-align:center;font-weight:700;line-height:1.18;letter-spacing:-.01em;
 top:{ 700 if deco=="blob" else (270 if deco=="mail" else 140)}px; bottom:{ 220 if deco!="mail" else 250}px}}
.logo{{position:absolute;bottom:74px;left:0;right:0;text-align:center;font-size:44px;font-weight:600;color:{s["fg"]}}}
.logo b{{color:{s["acc"] if s["k"] not in ("terra","olive") else s["fg"]};font-weight:700}}
.sub{{position:absolute;bottom:136px;left:0;right:0;text-align:center;font-family:Assistant;font-size:32px;font-weight:600;opacity:.8}}
</style></head><body>
{mail}{stamp}{'<div class="hand">הזמנה</div>' if deco=="mail" else ''}
{deco_html}
<div class="txt"><div id="t">{html.escape(text)}</div></div>
<div class="sub">מפגשי תנועה קבועים בהרצליה</div>
<div class="logo">יוצאים <b>להרפתקה</b></div>
<script>
const t=document.getElementById('t'), box=t.parentElement;
let fs=128; t.style.fontSize=fs+'px';
const maxH=box.clientHeight, maxW=box.clientWidth;
while((t.scrollHeight>maxH||t.scrollWidth>maxW) && fs>40){{ fs-=4; t.style.fontSize=fs+'px'; }}
t.style.maxWidth=maxW+'px';
</script></body></html>'''

def main():
    lines = [l.strip() for l in (ROOT/"ads"/"sentences.txt").read_text(encoding="utf-8").splitlines() if l.strip()]
    out = ROOT/"ads"/"img"; out.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp())
    items = []
    only = int(sys.argv[1]) if len(sys.argv) > 1 else None
    for i, text in enumerate(lines):
        name = f"ad-{i+1:02d}.png"
        items.append({"file": name, "text": text})
        if only is not None and i+1 != only: continue
        f = tmp/f"{i}.html"; f.write_text(page(text, i), encoding="utf-8")
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{H}", "--virtual-time-budget=6000",
                        f"--screenshot={out/name}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print("ok", name, text[:30])
    (ROOT/"ads"/"ads.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
if __name__ == "__main__":
    main()
