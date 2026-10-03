# מייצר תמונת מודעה (1080x1350, יחס 4:5) לכל שורה ב-ads/sentences.txt
# טקסט בשני צבעים: מה שבתוך [ ] מודגש בצבע ההדגשה. בלי צילומים.
# הרצה:  python ads/tools/build_ads.py [מספר-תמונה]   (דורש Chrome)
import os, sys, json, subprocess, html, tempfile, pathlib
from concurrent.futures import ThreadPoolExecutor
ROOT = pathlib.Path(__file__).resolve().parents[2]
CHROME = next(p for p in [r"C:\Program Files\Google\Chrome\Application\chrome.exe", r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"] if os.path.exists(p))
W, H = 1080, 1350

# (רקע, צבע טקסט ראשי, צבע הדגשה, עיגולי קישוט)
STYLES = [
  ("#F6EFE4", "#3F382F", "#C96F52", "rgba(232,213,190,.75)"),
  ("#C96F52", "#FFFDF9", "#FFE2A8", "rgba(255,253,249,.14)"),
  ("#E8D5BE", "#3F382F", "#B85C40", "rgba(255,253,249,.45)"),
  ("#686A48", "#FFFDF9", "#F4C77A", "rgba(255,253,249,.12)"),
  ("#663F4C", "#FFFDF9", "#F2B8A2", "rgba(255,253,249,.10)"),
  ("#FFFDF9", "#3F382F", "#C96F52", "rgba(232,213,190,.6)"),
  ("#DDDCC3", "#3F382F", "#A9533A", "rgba(255,253,249,.5)"),
]
# מיקומי עיגולי הקישוט (שונים מתמונה לתמונה)
DECOS = [
  ((-170, None, 560, 620, None), (None, -90, 380, 380, 0)),
  ((None, -150, 520, 620, None), (-110, None, 420, 420, None)),
]

def colored(text):
    out, i = [], 0
    while i < len(text):
        a = text.find("[", i)
        if a < 0:
            out.append(html.escape(text[i:])); break
        b = text.find("]", a)
        out.append(html.escape(text[i:a]))
        out.append("<em>" + html.escape(text[a+1:b]) + "</em>")
        i = b + 1
    return "".join(out)

def page(text, i):
    bg, fg, acc, deco = STYLES[i % len(STYLES)]
    flip = (i // len(STYLES)) % 2
    return f'''<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600&family=Rubik:wght@600;700&family=Assistant:wght@600&display=swap" rel="stylesheet">
<style>
*{{box-sizing:border-box;margin:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{background:{bg};color:{fg};font-family:Fredoka,Rubik,sans-serif;position:relative}}
.c1{{position:absolute;{'left' if flip else 'right'}:-170px;top:-240px;width:620px;height:620px;border-radius:50%;background:{deco}}}
.c2{{position:absolute;{'right' if flip else 'left'}:-130px;bottom:-70px;width:400px;height:520px;border-radius:200px 200px 0 0;background:{deco}}}
.txt{{position:absolute;left:96px;right:96px;top:200px;bottom:300px;display:flex;align-items:center;justify-content:center;text-align:center}}
#t{{font-weight:600;line-height:1.22;letter-spacing:-.005em}}
#t em{{font-style:normal;color:{acc}}}
.sub{{position:absolute;bottom:150px;left:0;right:0;text-align:center;font-family:Assistant;font-size:32px;font-weight:600;opacity:.8}}
.logo{{position:absolute;bottom:84px;left:0;right:0;text-align:center;font-family:Rubik;font-size:46px;font-weight:600}}
.logo b{{color:{acc};font-weight:700}}
</style></head><body>
<div class="c1"></div><div class="c2"></div>
<div class="txt"><div id="t">{colored(text)}</div></div>
<div class="sub">מפגשים מסוג אחר</div>
<div class="logo">יוצאים <b>להרפתקה</b></div>
<script>
const t=document.getElementById('t'), box=t.parentElement;
let fs=150; t.style.fontSize=fs+'px';
while((t.scrollHeight>box.clientHeight||t.scrollWidth>box.clientWidth) && fs>40){{ fs-=4; t.style.fontSize=fs+'px'; }}
</script></body></html>'''

def render(args):
    i, text, tmp, out = args
    name = f"ad-{i+1:02d}.png"
    f = tmp / f"{i}.html"; f.write_text(page(text, i), encoding="utf-8")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{H}", "--virtual-time-budget=6000",
                    f"--user-data-dir={tmp/('p'+str(i))}", f"--screenshot={out/name}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return name

def main():
    lines = [l.strip() for l in (ROOT/"ads"/"sentences.txt").read_text(encoding="utf-8").splitlines() if l.strip()]
    out = ROOT/"ads"/"img"; out.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp())
    only = int(sys.argv[1]) if len(sys.argv) > 1 else None
    items = [{"file": f"ad-{i+1:02d}.png", "text": t.replace("[", "").replace("]", "")} for i, t in enumerate(lines)]
    jobs = [(i, t, tmp, out) for i, t in enumerate(lines) if only is None or i+1 == only]
    with ThreadPoolExecutor(max_workers=4) as ex:
        for n in ex.map(render, jobs): print("ok", n, flush=True)
    (ROOT/"ads"/"ads.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")

if __name__ == "__main__":
    main()
