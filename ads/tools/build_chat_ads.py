# מודעות פייסבוק לצ'אט (chat/): תמונת טקסט 9:16 (1080x1920), כל התוכן באזור בטוח 4:5, שני צבעים, בלי צילומים.
# הטקסטים מ-chat/openers.json (המפתח = ?c= בקישור). מה שב-[ ] מודגש. בתחתית: שורת הפניה לכפתור של פייסבוק שמתחת למודעה (חץ למטה), במקום שורת החיפוש של מודעות הגוגל.
# הרצה: python ads/tools/build_chat_ads.py   -> ads/chat/img/chat-<מפתח>-916.png  (דורש Chrome)
import json, pathlib, subprocess, tempfile, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import build_ads as B
ROOT = B.ROOT
# מפתח -> (המשפט, צבע הדגשה חי מהפלטה: coral / sage / terra, על רקע ink). שורות רגילות מימין לשמאל, וההדגשה גדולה יותר בשורה משלה.
ADS = {
  "touch": ("כמה זמן עבר מאז שמישהו [חיבק] אותנו בלי סיבה?", "#FF8A5C"),
  "mask": ("העייפות הכי גדולה היא לא מהעבודה. היא מלהיות [בסדר] כל היום", "#8DB255"),
  "numb": ("הכי מפחיד זה לא שהכול רע. זה שהכול בסדר, [ואנחנו כבר לא מרגישים]", "#E5562D"),
}
CTA = "לחצו על הכפתור למטה ונדבר"

def page(text, acc):
    bg, fg, deco = "#2C231D", "#FFF5E8", "rgba(255,245,232,.07)"   # ink, cream
    top, bot = B.SAFE + 120, B.SAFE + 350
    ch = B.H - top - bot
    return f'''<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600&family=Rubik:wght@500;600;700&display=swap" rel="stylesheet">
<style>
*{{box-sizing:border-box;margin:0}}
html,body{{width:{B.W}px;height:{B.H}px;overflow:hidden}}
body{{background:{bg};color:{fg};font-family:Fredoka,Rubik,sans-serif;position:relative}}
.c1{{position:absolute;right:-150px;top:{B.SAFE-240}px;width:620px;height:620px;border-radius:50%;background:{deco}}}
.c2{{position:absolute;left:-130px;bottom:0;width:400px;height:{450+B.SAFE}px;border-radius:200px 200px 0 0;background:{deco}}}
.main{{position:absolute;left:90px;right:90px;top:{top}px;height:{ch}px;display:flex;align-items:center;justify-content:center;text-align:center}}
#t{{font-weight:600;line-height:1.18}}
#t em{{font-style:normal;color:{acc};display:block;font-size:1.32em;line-height:1.12;margin:.08em 0}}
.chat{{position:absolute;bottom:{B.SAFE+112}px;left:50%;transform:translateX(-50%);height:124px;display:flex;align-items:center;gap:26px;
  padding:0 46px 0 18px;border-radius:999px;background:#FFF5E8;border:0;box-shadow:0 10px 30px rgba(0,0,0,.35);white-space:nowrap}}
.chat .q{{font-family:Rubik;font-size:52px;font-weight:500;color:#2C231D;line-height:1;display:flex;align-items:center}}
.chat .caret{{display:inline-block;width:5px;height:60px;border-radius:3px;background:#E5562D;margin-right:16px}}
.chat .go{{width:88px;height:88px;border-radius:50%;background:#E5562D;display:grid;place-items:center;flex:none;margin-right:6px}}
.chat .go svg{{width:44px;height:44px}}
</style></head><body>
<div class="c1"></div><div class="c2"></div>
<div class="main"><div id="t">{B.colored(text)}</div></div>
<div class="chat"><span class="q">{CTA}</span>
<span class="go"><svg viewBox="0 0 24 24" fill="none" stroke="#FFFDF9" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v15"/><path d="m5.5 12.5 6.5 6.5 6.5-6.5"/></svg></span></div>
<script>
const t=document.getElementById('t'), box=t.parentElement;
let fs=130; t.style.fontSize=fs+'px';
while((t.offsetHeight>box.clientHeight||t.offsetWidth>box.clientWidth) && fs>30){{ fs-=4; t.style.fontSize=fs+'px'; }}
</script></body></html>'''

def main():
    out = ROOT/"ads"/"chat"/"img"; out.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp())
    openers = json.loads((ROOT/"chat"/"openers.json").read_text(encoding="utf-8"))["items"]
    for key, (text, acc) in ADS.items():
        assert key not in openers or B.plain(text).replace("'", "") == openers[key]["ad"].replace("‘", "").replace("’", "").replace("'", ""), key + ": הטקסט שונה מ-chat/openers.json"
        f = tmp/(key+".html"); f.write_text(page(text, acc), encoding="utf-8")
        name = f"chat-{key}-916.png"
        subprocess.run([B.CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--window-size={B.W},{B.H}", "--virtual-time-budget=6000",
                        f"--user-data-dir={tmp/('p'+key)}", f"--screenshot={out/name}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print("ok", name)

if __name__ == "__main__":
    main()
