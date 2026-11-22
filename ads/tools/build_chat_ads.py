# מודעות פייסבוק לצ'אט (chat/): תמונת טקסט 9:16 (1080x1920). כל התוכן באזור הבטוח 4:5 (1080x1350, y 285 עד 1635), שני צבעים, בלי צילומים.
# מלבן 4:5 דמיוני באמצע עם ריפוד של 90px, והטקסט ממלא את פנים הריפוד (900x1170): כל שורה מוגדלת או מוקטנת לאותו רוחב בדיוק,
# והמרווח האנכי מתפזר כך שגם הגובה מתמלא. מילים קצרות וחזקות נעשות ענקיות, שורות ארוכות קטנות. השורה האחרונה מפנה לכפתור של פייסבוק שמתחת למודעה.
# הטקסט המלא חייב להיות זהה ל-chat/openers.json (בלי נקודות בתמונה). הרצה: python ads/tools/build_chat_ads.py  -> ads/chat/img/chat-<מפתח>-916.png  (דורש Chrome)
import json, pathlib, subprocess, tempfile, sys, html
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import build_ads as B
ROOT = B.ROOT
PAD = 90
IN_W, IN_H = B.W - 2 * PAD, 1350 - 2 * PAD       # פנים הריפוד: 900x1170
CTA = "לחצו על הכפתור למטה ונדבר"
# מפתח -> (שורות (טקסט, צבע), צבע הדגשה חי מהפלטה: coral / sage / terra, על רקע ink)
ADS = {
  "touch": ([("כמה זמן עבר", "fg"), ("מאז שמישהו", "fg"), ("חיבק", "acc"), ("אותנו", "fg"), ("בלי סיבה?", "fg")], "#FF8A5C"),
  "mask": ([("העייפות הכי גדולה", "fg"), ("היא לא מהעבודה", "fg"), ("היא מלהיות", "fg"), ("בסדר", "acc"), ("כל היום", "fg")], "#8DB255"),
  "numb": ([("הכי מפחיד", "fg"), ("זה לא שהכול רע", "fg"), ("זה שהכול בסדר,", "fg"), ("ואנחנו כבר", "acc"), ("לא מרגישים", "acc")], "#E5562D"),
}

FONT = "Secular One"   # גופן מרובע וכבד (בלי עיגול). חלופה: Heebo 900
def page(lines, acc):
    bg, fg, deco = "#2C231D", "#FFF5E8", "rgba(255,245,232,.07)"   # ink, cream
    data = json.dumps([[t, c] for t, c in lines], ensure_ascii=False)
    fam = FONT.replace(" ", "+")
    return f'''<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family={fam}&display=block" rel="stylesheet">
<style>*{{margin:0}}html,body{{width:{B.W}px;height:{B.H}px;overflow:hidden;background:{bg}}}canvas{{display:block}}pre{{display:none}}</style></head><body>
<canvas id="c" width="{B.W}" height="{B.H}"></canvas><pre id="s"></pre>
<script>
// פריסה לפי הדיו עצמו: כל שורה ברוחב דיו של IN_W בדיוק, מרווחים אנכיים שווים וצפופים, וריפוד זהה מארבעת הצדדים של המלבן 4:5.
// הטקסט מפוצל לשורות כך שהגובה ימלא את המלבן בדיוק עם מרווח קטן; מילה מודגשת תמיד בשורה משלה, והשורה האחרונה (ההפניה לכפתור) קבועה.
const SRC={data}, CTA={json.dumps(CTA, ensure_ascii=False)}, ACC='{acc}', FG='{fg}', W={B.W}, H={B.H}, X0={PAD}, Y0={B.SAFE}+{PAD}, IN_W={IN_W}, IN_H={IN_H}, FAM='"{FONT}"', GAP=14;
const c=document.getElementById('c'), x=c.getContext('2d');
function ink(t, fs){{ x.font=fs+'px '+FAM; x.direction='rtl'; const m=x.measureText(t); return {{l:m.actualBoundingBoxLeft, r:m.actualBoundingBoxRight, a:m.actualBoundingBoxAscent, d:m.actualBoundingBoxDescent}}; }}
function fit(t){{ const i=ink(t,100), fs=100*IN_W/Math.abs(i.l+i.r), j=ink(t,fs); return {{fs, h:j.a+j.d}}; }}
// קבוצות רצופות לפי צבע; בתוך קבוצת טקסט רגיל מותר לפצל לכמה שורות
function groups(){{ const g=[]; for(const [t,col] of SRC){{ const last=g[g.length-1]; if(last&&last.col===col&&col==='fg') last.t.push(t); else g.push({{col, t:[t]}}); }} return g; }}
function go(){{
  x.fillStyle='{bg}'; x.fillRect(0,0,W,H); x.fillStyle='{deco}'; x.beginPath(); x.arc(W+160,{B.SAFE-240}+230,310,0,7); x.fill();
  x.beginPath(); x.moveTo(-130,H); x.lineTo(-130,H-{450+B.SAFE}+200); x.arc(70,H-{450+B.SAFE}+200,200,Math.PI,0); x.lineTo(270,H); x.fill();
  // מועמדים לשורות: כל SRC כבר מפוצל לשורות לפי הכותרות; אפשר לאחד שורות סמוכות מאותו צבע, או (כאן) להשאיר כמו שהן ולכוון רק רווחים.
  let lines=SRC.map(([t,c])=>({{t,c}})); lines.push({{t:CTA, c:'acc'}});
  const m=lines.map(l=>fit(l.t)); let sum=m.reduce((p,q)=>p+q.h,0), n=lines.length, gap=(IN_H-sum)/(n-1), k=1;
  if(gap<GAP){{ k=(IN_H-GAP*(n-1))/sum; gap=GAP; }}
  let y=Y0, stats=[]; const ws=IN_W*k, left=X0+(IN_W-ws)/2;
  lines.forEach((l,i)=>{{ const fs=m[i].fs*k, j=ink(l.t,fs); x.font=fs+'px '+FAM; x.direction='rtl'; x.textAlign='right'; x.fillStyle=l.c==='acc'?ACC:FG;
    x.fillText(l.t, left+ws-j.r, y+j.a); stats.push([Math.round(left),Math.round(y),Math.round(left+ws),Math.round(y+j.a+j.d)]); y+=j.a+j.d+gap; }});
  document.getElementById('s').textContent=JSON.stringify({{k,gap,sum,stats}});
}}
document.fonts.load('100px {FONT}','אבגדהוזחטיכלמנסעפצקרשת?').then(()=>setTimeout(go,50));
</script></body></html>'''

def main():
    out = ROOT/"ads"/"chat"/"img"; out.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp())
    openers = json.loads((ROOT/"chat"/"openers.json").read_text(encoding="utf-8"))["items"]
    for key, (lines, acc) in ADS.items():
        full = " ".join(t for t, _ in lines)
        assert key not in openers or full == openers[key]["ad"].replace(".", "").replace("‘", "").replace("’", "").replace("'", ""), key + ": הטקסט שונה מ-chat/openers.json: " + full
        f = tmp/(key+".html"); f.write_text(page(lines, acc), encoding="utf-8")
        name = f"chat-{key}-916.png"
        subprocess.run([B.CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--window-size={B.W},{B.H}", "--virtual-time-budget=6000",
                        f"--user-data-dir={tmp/('p'+key)}", f"--screenshot={out/name}", f.as_uri()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print("ok", name)

if __name__ == "__main__":
    main()
