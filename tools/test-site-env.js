/* סביבת בדיקות (test.harpatka.co.il). הקובץ נוצר ומוזרק רק לבניית הבדיקות (tools/deploy-test.py), לא קיים באתר האמיתי.
   1. כל בקשה לבסיס הנתונים הולכת לסכמת test (נתונים נפרדים מהאמיתיים).
   2. מעקב (Pixel / Google Analytics) הוסר בבנייה; כאן רק מגנים שקריאות מהקוד לא ייכשלו.
   3. תגית קטנה "סביבת בדיקות" בפינה. */
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
  /* התגית בשכבה העליונה של הדפדפן (popover): מעל הכל, גם מעל פופאפים (dialog); כשנפתח dialog היא מורמת מחדש */
  function raise(el) { try { el.hidePopover(); el.showPopover(); } catch (x) {} }
  function badge() {
    if (document.getElementById('testEnvBadge') || document.getElementById('testBar')) return;
    var d = document.createElement('div');
    d.id = 'testEnvBadge';
    d.setAttribute('popover', 'manual');
    d.textContent = 'בדיקות';
    d.setAttribute('style', 'inset:auto;margin:0;border:0;position:fixed;top:3px;right:6px;background:#C96F52;color:#fff;font:700 11px/1 Arial,sans-serif;padding:5px 9px;border-radius:999px;pointer-events:none;opacity:.8;overflow:visible');
    document.body.appendChild(d);
    raise(d);
    new MutationObserver(function (m) { if (m.some(function (r) { return r.target.nodeName === 'DIALOG'; })) raise(d); }).observe(document.documentElement, { subtree: true, attributes: true, attributeFilter: ['open'] });
  }
  if (document.body) badge(); else document.addEventListener('DOMContentLoaded', badge);
})();
