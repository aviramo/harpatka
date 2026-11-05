/* סליידר עדויות (5.11.26): גלילה אופקית עם הצמדה (אפשר להחליק ימינה ושמאלה), מתנגן אוטומטית. **נעצר בלחיצה** (על הסליידר, על חץ או על כפתור העצירה), במקש חץ או בגלילה אופקית (החלקה ימינה או שמאלה) ונשאר עצור עד לחיצה על כפתור ההפעלה; גלילה אנכית של הדף לא עוצרת אותו.
   גלילה אנכית של הדף (גם כשהאצבע או העכבר על הסליידר) לא משפיעה על הנגן ועל התזמון. רק כשהסליידר או הדף לא בתצוגה (או בפוקוס מקלדת) הספירה מושהית, ו**ממשיכה בדיוק מאותה נקודה** כשחוזרים; ספירה חדשה מתחילה רק במעבר לעדות אחרת. מכבד prefers-reduced-motion (בלי ניגון אוטומטי).
   סדר השקופיות אקראי בכל טעינה כשיש data-shuffle. שימוש: <div class="vc-car" data-carousel data-interval="6500" data-shuffle> עם .vc-track (השקופיות), .vc-prev, .vc-next, .vc-toggle, .vc-cnt ו-.vc-fill */
(function () {
  function init(root) {
    var track = root.querySelector('.vc-track');
    if (!track || !track.children.length) return;
    if (root.hasAttribute('data-shuffle')) {   // סדר אקראי בכל טעינה (Fisher-Yates)
      var arr = [].slice.call(track.children);
      for (var i = arr.length - 1; i > 0; i--) { var j = Math.floor(Math.random() * (i + 1)), t = arr[i]; arr[i] = arr[j]; arr[j] = t; }
      arr.forEach(function (el) { track.appendChild(el); });
    }
    var slides = [].slice.call(track.children), n = slides.length;
    var prev = root.querySelector('.vc-prev'), next = root.querySelector('.vc-next'), toggle = root.querySelector('.vc-toggle'), cnt = root.querySelector('.vc-cnt'), fill = root.querySelector('.vc-fill');
    var iv = Number(root.getAttribute('data-interval')) || 6500, mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    var idx = 0, timer = 0, stopped = mq.matches, hold = false, vis = false, moving = 0, syncT = 0;
    var remain = iv, startedAt = 0, armed = false;   // כמה זמן נשאר עד ההחלפה הבאה (נשמר בהשהיות)
    var rtl = getComputedStyle(root).direction === 'rtl';
    root.style.setProperty('--vc-iv', iv + 'ms');
    slides.forEach(function (s, k) { s.setAttribute('aria-label', (k + 1) + ' מתוך ' + n); });

    function centerOf(k) { var s = slides[k]; return s.offsetLeft - (track.clientWidth - s.offsetWidth) / 2; }
    function active() { return !stopped && !hold && vis && !document.hidden; }
    function arm() {   // ממשיכים את הספירה ממה שנשאר
      clearTimeout(timer); startedAt = Date.now(); armed = true;
      timer = setTimeout(function () { armed = false; go(idx + 1, true); }, remain);
    }
    function disarm() {   // השהיה: שומרים כמה זמן נשאר, ולא מאפסים
      if (armed) { remain = Math.max(250, remain - (Date.now() - startedAt)); armed = false; }
      clearTimeout(timer);
    }
    function sync() {   // מצב הניגון לפי התנאים: ממשיך או משהה, בלי איפוס
      var on = active();
      root.classList.toggle('wait', !on && !stopped);   // הפס מוקפא במקומו
      if (on) { if (!armed) arm(); } else disarm();
    }
    function restart() {   // עדות חדשה: ספירה חדשה מההתחלה
      clearTimeout(timer); armed = false; remain = iv;
      if (fill) { fill.classList.remove('run'); void fill.offsetWidth; if (!stopped) fill.classList.add('run'); }
      sync();
    }
    function setStopped(v) {
      stopped = v; root.classList.toggle('stopped', v);
      if (toggle) { toggle.setAttribute('aria-pressed', v ? 'true' : 'false'); toggle.setAttribute('aria-label', v ? 'הפעלת ההחלפה האוטומטית' : 'עצירת ההחלפה האוטומטית'); }
      track.setAttribute('aria-live', v ? 'polite' : 'off');
      if (v) { disarm(); if (fill) fill.classList.remove('run'); root.classList.remove('wait'); } else restart();   // הפעלה אחרי עצירה: ספירה חדשה
    }
    function mark(k) {
      idx = k;
      slides.forEach(function (s, q) { s.classList.toggle('on', q === k); });
      if (cnt) cnt.innerHTML = '<bdi>' + (k + 1) + ' / ' + n + '</bdi>';
    }
    function go(k, smooth) {
      k = (k + n) % n; mark(k);
      var animate = smooth && !mq.matches;
      moving = animate ? Date.now() + 900 : 0;   // בזמן גלילה יזומה לא מסנכרנים את המצב מהגלילה
      track.scrollTo({ left: centerOf(k), behavior: animate ? 'smooth' : 'auto' });
      restart();
    }
    function userMoved() { if (!stopped) setStopped(true); }   // המשתתף עצר: לחיצה או גלילה אופקית
    function syncFromScroll() {
      if (moving && Date.now() < moving) return;
      var mid = track.scrollLeft + track.clientWidth / 2, best = 0, bd = Infinity;
      slides.forEach(function (s, q) { var d = Math.abs(s.offsetLeft + s.offsetWidth / 2 - mid); if (d < bd) { bd = d; best = q; } });
      if (best !== idx) { mark(best); restart(); }
    }

    track.addEventListener('scroll', function () { clearTimeout(syncT); syncT = setTimeout(syncFromScroll, 110); }, { passive: true });
    track.addEventListener('click', userMoved);   // לחיצה (נגיעה קצרה) עוצרת
    var tx = 0, ty = 0;   // נגיעה: גלילה אופקית (החלקה) עוצרת; גלילה אנכית של הדף לא משפיעה בכלל על הנגן ועל התזמון
    track.addEventListener('touchstart', function (e) { tx = e.touches[0].clientX; ty = e.touches[0].clientY; }, { passive: true });
    track.addEventListener('touchmove', function (e) { var dx = Math.abs(e.touches[0].clientX - tx), dy = Math.abs(e.touches[0].clientY - ty); if (dx > 8 && dx > dy) userMoved(); }, { passive: true });
    track.addEventListener('wheel', function (e) { if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) userMoved(); }, { passive: true });   // גלילה אופקית בלבד
    track.addEventListener('keydown', function (e) {
      var fwd = rtl ? 'ArrowLeft' : 'ArrowRight', back = rtl ? 'ArrowRight' : 'ArrowLeft';
      if (e.key === fwd) { e.preventDefault(); userMoved(); go(idx + 1, true); }
      else if (e.key === back) { e.preventDefault(); userMoved(); go(idx - 1, true); }
    });
    if (next) next.addEventListener('click', function () { userMoved(); go(idx + 1, true); });
    if (prev) prev.addEventListener('click', function () { userMoved(); go(idx - 1, true); });
    if (toggle) toggle.addEventListener('click', function () { setStopped(!stopped); });
    track.addEventListener('focus', function () { try { if (track.matches(':focus-visible')) { hold = true; sync(); } } catch (e) {} });   // השהיה רק בפוקוס מקלדת על הסליידר (לא אחרי לחיצה או נגיעה, ולא על הכפתורים)
    track.addEventListener('blur', function () { hold = false; sync(); });
    document.addEventListener('visibilitychange', sync);
    window.addEventListener('resize', function () { clearTimeout(syncT); syncT = setTimeout(function () { track.scrollTo({ left: centerOf(idx), behavior: 'auto' }); }, 150); });
    if ('IntersectionObserver' in window) new IntersectionObserver(function (es) { vis = es[0].isIntersecting; sync(); }, { threshold: 0.4 }).observe(root); else vis = true;
    mq.addEventListener && mq.addEventListener('change', function () { if (mq.matches) setStopped(true); });
    setStopped(stopped); go(0, false);
  }
  window.HarpatkaCarousel = init;
  [].forEach.call(document.querySelectorAll('[data-carousel]'), init);
})();
