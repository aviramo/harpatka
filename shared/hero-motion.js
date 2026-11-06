/* אפקט תנועה בפתיח: הסרטים הכתומים מצטיירים לאורך המסלול שלהם (שאר האפקט ב-shared/site.css).
   פעיל רק כשעל html יש class "hero-motion" (להסרת האפקט כולו: להסיר אותו מה-html). לא מופעל כשמוגדרת הפחתת תנועה. */
(function () {
  var root = document.documentElement;
  if (!root.classList.contains('hero-motion')) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  function ready(fn) { if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn); else fn(); }
  ready(function () {
    /* 2. הסרטים הכתומים: גדלים לאורך המסלול (החצי הראשון של הנקודות הוא הקצה העליון, והשני הקצה התחתון בסדר הפוך) */
    var starts = [0.15, 0.3], dur = 1.0;   /* הקווים סביב התמונה נמשכים יחד עם כניסת התמונה, תוך שנייה */
    document.querySelectorAll('#invite .h8-flow').forEach(function (svg) {
      svg.querySelectorAll('polygon').forEach(function (poly, k) {
        var pts = poly.getAttribute('points').trim().split(' '), n = pts.length / 2;
        var P = pts.slice(0, n), Q = pts.slice(n).reverse();
        if (!svg.classList.contains('fm') && parseFloat(P[0]) < parseFloat(P[P.length - 1])) { P.reverse(); Q.reverse(); }   /* כל הסרטים נבנים מימין לשמאל, חוץ מהגלים שמעל ומתחת לתמונה במובייל (.fm), שנבנים משמאל לימין לבקשת בעל האתר */
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
