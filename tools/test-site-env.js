/* סביבת בדיקות (test.harpatka.co.il). הקובץ נוצר ומוזרק רק לבניית הבדיקות (tools/deploy-test.py), לא קיים באתר האמיתי.
   1. כל בקשה לבסיס הנתונים הולכת לסכמת test (נתונים נפרדים מהאמיתיים).
   2. מעקב (Pixel / Google Analytics) הוסר בבנייה; כאן רק מגנים שקריאות מהקוד לא ייכשלו.
   3. פס "סביבת בדיקות" בראש הדף. נטען בראש ה-<head> (סקריפט חוסם), ולכן המקום של הפס שמור כבר לפני שהדף מצויר;
      הפס עצמו כתוב ב-HTML מיד אחרי <body> (deploy-test.py), כך שהוא מופיע יחד עם הדף, בלי קפיצה (31.10.26). */
(function () {
  window.HARPATKA_ENV = { name: 'test', schema: 'test' };
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {};
  var origFetch = window.fetch;
  window.fetch = function (input, init) {
    try {
      var url = typeof input === 'string' ? input : (input && input.url) || '';
      if (url.indexOf('.supabase.co/rest/v1/') !== -1) {
        var h = new Headers((init && init.headers) || (input && input.headers) || {});
        h.set('Accept-Profile', 'test');
        h.set('Content-Profile', 'test');
        init = Object.assign({}, init || {}, { headers: h });
      }
    } catch (e) {}
    return origFetch.call(this, input, init);
  };
  var TOP = window.self === window.top;   // בתוך iframe (פופאפ האזור האישי, צפייה כמשתתף): בלי פס, הוא כבר בדף הראשי
  /* המקום של הפס (18px) שמור מראש: הדף מתחיל מתחתיו, ופופאפים שנפתחים מלמעלה מתחילים מתחתיו.
     הפופאפ נועל את הגוף ב-position:fixed; בלי margin-top על הגוף הדף שמאחור קופץ 18px למעלה */
  if (TOP) document.documentElement.classList.add('env-test');
  var st = document.createElement('style');
  st.textContent = 'html.env-test{margin-top:18px;--tbtop:18px}html.env-test.modal-lock body{margin-top:18px}html.env-test .modal{top:18px}' +
    '#testEnvBadge{inset:auto;margin:0;border:0;position:fixed;top:0;left:0;right:0;z-index:2147483647;width:auto;height:18px;padding:0;overflow:hidden;background:#3F382F;color:#fff;font:700 11px/18px Arial,sans-serif;text-align:center;pointer-events:none}' +
    'html:not(.env-test) #testEnvBadge{display:none!important}';
  (document.head || document.documentElement).appendChild(st);
  /* הפס בשכבה העליונה של הדפדפן (popover): מעל הכל, גם מעל פופאפים (dialog); כשנפתח dialog הוא מורם מחדש */
  function raise(el) { try { el.hidePopover(); el.showPopover(); } catch (x) {} }
  window.__envBadge = function () {
    if (!TOP) return;
    var d = document.getElementById('testEnvBadge');
    if (!d) {   // עמוד בלי הפס בתוך ה-HTML: יוצרים אותו (גיבוי)
      if (!document.body) return;
      d = document.createElement('div'); d.id = 'testEnvBadge'; d.textContent = 'סביבת בדיקות · נתונים נפרדים מהאמיתיים';
      document.body.insertBefore(d, document.body.firstChild);
    }
    if (d.getAttribute('data-on')) return;
    d.setAttribute('data-on', '1');
    d.setAttribute('popover', 'manual');
    raise(d);
    new MutationObserver(function (m) { if (m.some(function (r) { return r.target.nodeName === 'DIALOG'; })) raise(d); }).observe(document.documentElement, { subtree: true, attributes: true, attributeFilter: ['open'] });
  };
  if (document.body) window.__envBadge(); else document.addEventListener('DOMContentLoaded', window.__envBadge);
})();
