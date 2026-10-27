/* באנר "המפגש הקרוב" (בבדיקה בלבד): מצייר מהמטמון המקומי מיד (בלי שלד בביקור חוזר), ואחרי טעינת המפגשים מהבסיס מתעדכן. גובה קבוע בכל המצבים. */
(function () {
  const bar = document.getElementById('topbar'), wrap = document.getElementById('tbWrap'); if (!bar || !wrap) return;
  const el = (id) => document.getElementById(id);
  const dayName = (iso) => ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'][new Date(iso + 'T12:00:00Z').getUTCDay()];
  const todayIso = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
  const render = (d) => {
    const nx = ((d && d.future) || []).filter((m) => m.date >= todayIso())[0] || null;
    bar.classList.remove('tb-loading');
    if (nx) {
      const [, mo, dd] = nx.date.split('-');
      el('tbPillT').textContent = 'המפגש הקרוב' + (nx.max ? ' · ' + nx.max + ' משתתפים' : '');
      el('tbMain').textContent = 'יום ' + dayName(nx.date) + ' ' + Number(dd) + '.' + Number(mo) + ' · ' + nx.time;
      el('tbSub').textContent = [nx.name, String(nx.dir || '').split('\n')[0]].filter(Boolean).join(' · ') || ' ';
    } else {
      el('tbPillT').textContent = 'בקרוב';
      el('tbMain').textContent = 'המפגש הבא בדרך אליכם';
      el('tbSub').textContent = 'השאירו פרטים ונעדכן ברגע שהתאריך נקבע';
    }
  };
  let cached = null;
  try { cached = JSON.parse(localStorage.getItem(typeof MEET_CACHE !== 'undefined' ? MEET_CACHE : 'harpatka_meetings_v11') || 'null'); } catch (e) {}
  if (cached && cached.future) render(cached);
  if (typeof meetingsReady !== 'undefined') meetingsReady.then((d) => { if (d) render(d); else if (!cached) render(null); });
  else if (!cached) render(null);
  /* הצטמצמות צמודה לגלילה (--p מ-0 עד 1 לאורך 110px), עם גובה שמור שלא קופץ */
  const RANGE = 110; let ticking = false;
  const apply = () => { ticking = false; bar.style.setProperty('--p', Math.min(1, Math.max(0, (window.scrollY || document.documentElement.scrollTop) / RANGE)).toFixed(3)); };
  const measure = () => { const cur = bar.style.getPropertyValue('--p'); bar.style.setProperty('--p', '0'); const h = bar.offsetHeight; bar.style.setProperty('--p', cur || '0'); if (h) wrap.style.height = h + 'px'; };
  measure(); apply();
  window.addEventListener('load', measure); window.addEventListener('resize', measure);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(measure);
  window.addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(apply); } }, { passive: true });
})();
