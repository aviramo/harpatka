/* אפקט תנועה בפתיח: אותיות הכותרת נכנסות בגל זורם, והסרטים הכתומים מצטיירים לאורך המסלול שלהם (שאר האפקט ב-shared/site.css).
   פעיל רק כשעל html יש class "hero-motion" (להסרת האפקט כולו: להסיר אותו מה-html). לא מופעל כשמוגדרת הפחתת תנועה. */
(function () {
  var root = document.documentElement;
  if (!root.classList.contains('hero-motion')) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  function ready(fn) { if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn); else fn(); }
  ready(function () {
    /* 1. הכותרת: כל אות בנפרד, כדי שיעבור בה גל. הקריאה לקוראי מסך נשארת בכותרת עצמה */
    var h1 = document.querySelector('#invite .h8-h1');
    if (h1 && !h1.dataset.split) {
      var keys = {}; h1.querySelectorAll('.h8-key').forEach(function (k) { k.textContent.trim().split(/\s+/).forEach(function (w) { keys[w] = 1; }); });   // המילים המודגשות בצבע נשארות מודגשות אחרי הפיצול לאותיות
      var txt = h1.textContent.replace(/\s+/g, ' ').trim(), i = 0;
      h1.dataset.split = '1'; h1.setAttribute('aria-label', txt); h1.textContent = '';
      txt.split(' ').forEach(function (w, wi) {
        if (wi) h1.appendChild(document.createTextNode(' '));
        var ws = document.createElement('span'); ws.className = 'hw' + (keys[w] ? ' hkey' : ''); ws.setAttribute('aria-hidden', 'true');
        Array.from(w).forEach(function (ch) { var l = document.createElement('span'); l.className = 'hl'; l.textContent = ch; l.style.setProperty('--i', i++); ws.appendChild(l); });
        h1.appendChild(ws);
      });
    }
    /* 2. הסרטים הכתומים: גדלים לאורך המסלול (החצי הראשון של הנקודות הוא הקצה העליון, והשני הקצה התחתון בסדר הפוך) */
    var starts = [1.6, 2.1], dur = 2.6;
    document.querySelectorAll('#invite .h8-flow').forEach(function (svg) {
      svg.querySelectorAll('polygon').forEach(function (poly, k) {
        var pts = poly.getAttribute('points').trim().split(' '), n = pts.length / 2;
        var P = pts.slice(0, n), Q = pts.slice(n).reverse();
        poly.setAttribute('points', P[0] + ' ' + Q[0]);
        var t0 = performance.now() + starts[k % 2] * 1000;
        (function frame(now) {
          var p = Math.max(0, Math.min(1, (now - t0) / (dur * 1000)));
          var e = p < .5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
          var m = Math.max(1, Math.round(e * (n - 1)));
          if (p > 0) poly.setAttribute('points', P.slice(0, m + 1).concat(Q.slice(0, m + 1).reverse()).join(' '));
          if (p < 1) requestAnimationFrame(frame);
        })(performance.now());
      });
    });
  });
})();
