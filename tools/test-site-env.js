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
  function badge() {
    if (document.getElementById('testEnvBadge') || document.getElementById('testBar')) return;
    var d = document.createElement('div');
    d.id = 'testEnvBadge';
    d.textContent = 'בדיקות';
    d.setAttribute('style', 'position:fixed;left:8px;bottom:8px;z-index:2147483000;background:#C96F52;color:#fff;font:700 11px/1 Arial,sans-serif;padding:5px 9px;border-radius:999px;pointer-events:none;opacity:.8');
    document.body.appendChild(d);
  }
  if (document.body) badge(); else document.addEventListener('DOMContentLoaded', badge);
})();
