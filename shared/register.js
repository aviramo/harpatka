/* פופאפ הרשמה משותף (עמוד הבית, v6, ביודנסה).
 * מזריק את הפופאפ לעמוד, מחבר את כפתורי ה-CTA (data-contact), הטופס (Supabase), התשלום והוואטסאפ.
 * דורש: shared/config.js (CONFIG) ו-shared/register.css. נטען בסוף ה-body.
 * הכפתור בעמוד רק צריך data-contact. אין להעתיק את הקוד הזה לעמודים. */
(function () {
  const BASE = document.currentScript.src.replace(/shared\/register\.js.*$/, '');   // כתובת השורש של האתר (גם מתוך תיקיות משנה)
  const MODAL_HTML = `<div id="contactModal" class="modal" hidden role="dialog" aria-modal="true" aria-labelledby="contactTitle">
    <div class="modal-box">
      <button type="button" class="modal-close" data-close-modal aria-label="סגירה">&times;</button>
      <div id="cmChoose" hidden>
      <h2 id="contactTitle" class="h-sect text-[1.6rem] md:text-[2rem] mb-5">מעדיפים לשלוח הודעה? עם מי תרצו לדבר?</h2>
      <div class="grid grid-cols-2 gap-3">
        <a href="#" target="_blank" rel="noopener" data-wa="hadar" class="contact-opt">
          <img src="__BASE__images/hadar.jpg" width="400" height="400" alt="הדר לוריא">
          <b>הדר</b>
          <span><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5" fill="currentColor" aria-hidden="true"><path d="M.057 24l1.687-6.163a11.867 11.867 0 01-1.587-5.945C.16 5.335 5.495 0 12.057 0a11.82 11.82 0 018.413 3.488 11.824 11.824 0 013.48 8.414c-.003 6.557-5.338 11.892-11.893 11.892a11.9 11.9 0 01-5.688-1.448L.057 24zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884a9.86 9.86 0 001.51 5.26l-.999 3.648 3.477-.913zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.612-.916-2.207-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/></svg>וואטסאפ</span>
        </a>
        <a href="#" target="_blank" rel="noopener" data-wa="ofir" class="contact-opt">
          <img src="__BASE__images/ofir-v3.jpg" width="400" height="400" alt="אופיר אבירם">
          <b>אופיר</b>
          <span><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5" fill="currentColor" aria-hidden="true"><path d="M.057 24l1.687-6.163a11.867 11.867 0 01-1.587-5.945C.16 5.335 5.495 0 12.057 0a11.82 11.82 0 018.413 3.488 11.824 11.824 0 013.48 8.414c-.003 6.557-5.338 11.892-11.893 11.892a11.9 11.9 0 01-5.688-1.448L.057 24zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884a9.86 9.86 0 001.51 5.26l-.999 3.648 3.477-.913zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.612-.916-2.207-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/></svg>וואטסאפ</span>
        </a>
      </div>
      <button type="button" id="cmShowForm" class="mt-4 w-full rounded-full px-5 py-3.5 text-[1.05rem] font-bold" style="background:var(--sand);color:var(--ink)">חזרה לשמירת מקום בטופס</button>
      <p class="mt-4 text-[.98rem]"><a href="#" target="_blank" rel="noopener" data-updates class="underline underline-offset-4 decoration-2 text-terra font-bold">לא בטוחים עדיין? אפשר להצטרף לקבוצת העדכונים</a></p>
      </div>
      <div id="cmFormView" data-su-root>
        <div data-su="formWrap">
          <h2 class="h-sect text-[1.5rem] md:text-[1.9rem] mb-2 px-8">שמרו לכם מקום</h2>
          <p class="muted mb-5 text-[.95rem]">מספר המקומות מוגבל, והמקום נשמר אחרי מילוי הפרטים ותשלום</p>
          <form data-su="form" novalidate class="text-start">
            <input type="text" name="website" data-su="hp" class="su-hp" tabindex="-1" autocomplete="off" aria-hidden="true">
            <div class="flex gap-2">
              <input id="cmName" data-su="name" name="name" type="text" class="su-input flex-1 min-w-0" autocomplete="name" maxlength="60" placeholder="שם" aria-label="שם" required>
              <div class="su-seg" data-su="gender" role="radiogroup" aria-label="מגדר">
                <label><input type="radio" name="cmGender" value="male"><span>גבר</span></label>
                <label><input type="radio" name="cmGender" value="female"><span>אישה</span></label>
              </div>
            </div>
            <div data-su="nameErr" class="su-err" role="alert"></div>
            <div data-su="genderErr" class="su-err" role="alert"></div>
            <div class="flex gap-2 mt-2.5">
              <input id="cmPhone" data-su="phone" name="phone" type="tel" dir="ltr" inputmode="tel" class="su-input text-end flex-1 min-w-0" autocomplete="tel" maxlength="24" placeholder="טלפון" aria-label="טלפון" required>
              <input id="cmAge" data-su="age" name="age" type="number" inputmode="numeric" min="18" max="99" class="su-input shrink-0" style="width:5.2rem" autocomplete="off" placeholder="גיל" aria-label="גיל" required>
            </div>
            <div data-su="phoneErr" class="su-err" role="alert"></div>
            <div data-su="ageErr" class="su-err" role="alert"></div>
            <button data-su="btn" type="submit" class="btn-primary rounded-full px-5 md:px-8 py-3.5 text-[1.2rem] whitespace-nowrap w-full mt-4">שמירת מקום</button>
            <div data-su="fail" class="su-err mt-3 text-center" role="alert"></div>
          </form>
          <button type="button" id="cmBack" class="mt-4 underline underline-offset-4 decoration-2 muted font-semibold text-[.95rem]">מעדיפים וואטסאפ? אפשר לשלוח לנו הודעה</button>
        </div>
        <div data-su="done" hidden>
          <h2 class="h-sect text-[1.7rem] md:text-[2.2rem] mb-3">עוד צעד אחד ושומרים לכם מקום</h2>
          <p class="lead mb-1" style="color:var(--ink);font-weight:700">המקום נשמר רק אחרי תשלום</p>
          <p class="lead muted mb-5">מספר המקומות מוגבל, ומי ששילם קודם מקבל קודם</p>
          <a href="#" target="_blank" rel="noopener" data-paybox class="btn-primary rounded-full px-8 py-4 text-[1.3rem] inline-block">לתשלום <span data-price>80 ₪</span> ושמירת מקום</a>
          <p class="muted text-[.95rem] mt-3">בהערה לתשלום כדאי לכתוב את השם, כדי שנדע מי שילם</p>
          <p class="lead muted mt-8 mb-4">ובינתיים אפשר להצטרף לקבוצת העדכונים בוואטסאפ</p>
          <a href="#" target="_blank" rel="noopener" data-updates class="btn-green">הצטרפות לקבוצת העדכונים</a>
        </div>
      </div>
    </div>
  </div>`.replace(/__BASE__/g, BASE);
  document.body.insertAdjacentHTML('beforeend', MODAL_HTML);

  /* ===== מנגנון פופאפ כללי (משותף לכל ה-.modal) ===== */
  let modalLastFocus = null;
  function openModal(m){
    modalLastFocus = document.activeElement;
    m.hidden = false;
    requestAnimationFrame(() => m.classList.add('open'));
    document.body.style.overflow = 'hidden';
    const f = m.querySelector('[data-autofocus]') || m.querySelector('button, a');
    if (f) f.focus();
  }
  function closeModal(m){
    m.classList.remove('open');
    document.body.style.overflow = '';
    setTimeout(() => { m.hidden = true; }, 320);
    if (modalLastFocus) modalLastFocus.focus();
  }
  // כל פופאפ נסגר ב-X, בלחיצה על הרקע, וב-Esc
  document.querySelectorAll('.modal').forEach(m => {
    m.querySelectorAll('[data-close-modal]').forEach(b => b.addEventListener('click', () => closeModal(m)));
    m.addEventListener('click', (e) => { if (e.target === m) closeModal(m); });
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const open = document.querySelector('.modal.open');
    if (open) closeModal(open);
  });

  /* ===== הצטרפות לעדכונים — קישור ישיר לקבוצת הוואטסאפ (עד גיל 50), בלי פופאפ בחירה ===== */
  document.querySelectorAll('[data-updates]').forEach(el => { el.setAttribute('href', CONFIG.updatesGroupLink); });
  /* ===== תשלום בפייבוקס (בהודעת התודה אחרי ההרשמה): קישור לקבוצת התשלום, ו-InitiateCheckout ל-Pixel בלחיצה ===== */
  document.querySelectorAll('[data-paybox]').forEach(el => {
    el.setAttribute('href', CONFIG.payboxLink);
    el.addEventListener('click', () => { try { fbq('track', 'InitiateCheckout'); } catch (e) {} });
  });
  /* ===== הגעה ממודעה בתשלום: הקישור במודעות הוא ?s=p. הסימון נשמר למשך הביקור (גם אם עוברים בין עמודים) ונשלח עם ההרשמה ===== */
  const PAID = (() => {
    let v = new URLSearchParams(location.search).get('s') === 'p';
    try { if (v) sessionStorage.setItem('harpatka_s', 'p'); else v = sessionStorage.getItem('harpatka_s') === 'p'; } catch (e) {}
    return v;
  })();
  /* ===== טופס הרשמה: שם + טלפון -> Supabase (פונקציה harpatka_signup, admin/signup.sql) =====
     ולידציה ונרמול ל-E.164 זהים ללוגיקה בבסיס הנתונים (harpatka_normalize_phone).
     הרשומה נקשרת בבסיס הנתונים למפגש הקרוב (זה שבבאנר) כ"טרם שילם" */
  /* Lead חד ערכי למכשיר: נשלח לפיקסל פעם אחת בלבד לכל מכשיר/דפדפן (גם אם נרשמים או לוחצים על וואטסאפ שוב), לפי סימון ב-localStorage */
  const leadOnce = () => {
    if (!window.fbq) return;
    const K = 'harpatka_lead_sent';
    try { if (localStorage.getItem(K)) return; localStorage.setItem(K, '1'); }
    catch (e) { if (window.__leadSent) return; window.__leadSent = true; }   // בלי אחסון: פעם אחת לטעינת דף
    try { fbq('track', 'Lead'); } catch (e) {}
  };
  function normPhone(raw) {
    const s = String(raw || '').trim();
    if (!s) return '';
    let plus = s[0] === '+', d = s.replace(/\D/g, '');
    if (!d) return '';
    if (d.startsWith('00')) { plus = true; d = d.slice(2); }
    const IL = /^(5\d{8}|7\d{8}|[23489]\d{7})$/;
    if (plus) {
      if (d.startsWith('9720')) d = '972' + d.slice(4);
      if (d.length < 8 || d.length > 15 || d[0] === '0') return '';
      if (d.startsWith('972') && !IL.test(d.slice(3))) return '';
      return '+' + d;
    }
    if (d[0] === '0') return IL.test(d.slice(1)) ? '+972' + d.slice(1) : '';
    return '';
  }
  window.normPhone = normPhone;
  const suRoots = [];
  function initSignup(root) {
    const q = k => root.querySelector('[data-su="' + k + '"]');
    const form = q('form'); if (!form) return;
    const nameI = q('name'), phoneI = q('phone'), ageI = q('age'), btn = q('btn'), t0 = Date.now();
    const setErr = (input, errEl, msg) => { errEl.textContent = msg || ''; input.classList.toggle('bad', !!msg); };
    const showDone = () => { q('formWrap').hidden = true; q('done').hidden = false; };
    suRoots.push(showDone);
    nameI.addEventListener('input', () => setErr(nameI, q('nameErr'), ''));
    phoneI.addEventListener('input', () => setErr(phoneI, q('phoneErr'), ''));
    ageI.addEventListener('input', () => setErr(ageI, q('ageErr'), ''));
    const genderBox = q('gender');
    genderBox.addEventListener('change', () => { genderBox.classList.remove('bad'); q('genderErr').textContent = ''; });
    form.addEventListener('submit', async (e) => {
      e.preventDefault(); q('fail').textContent = '';
      const name = nameI.value.trim().replace(/\s+/g, ' '), norm = normPhone(phoneI.value);
      let ok = true;
      if (name.length < 2) { setErr(nameI, q('nameErr'), 'נא למלא שם'); ok = false; }
      if (!norm) { setErr(phoneI, q('phoneErr'), 'מספר הטלפון לא תקין'); ok = false; }
      const age = parseInt(ageI.value, 10);
      if (!(age >= 18 && age <= 99)) { setErr(ageI, q('ageErr'), 'נא למלא גיל תקין'); ok = false; }
      const gEl = genderBox.querySelector('input:checked'), gender = gEl ? gEl.value : null;
      if (!gender) { genderBox.classList.add('bad'); q('genderErr').textContent = 'נא לבחור'; ok = false; }
      if (!ok) return;
      const allDone = () => { suRoots.forEach(f => f()); };   // בלי שמירה בדפדפן: בכל טעינה של הדף הטופס מוצג מחדש
      if (q('hp').value || Date.now() - t0 < 1500) { allDone(); return; }   // בוט: מציגים הצלחה בלי לשמור
      btn.disabled = true; btn.textContent = 'שולחים...';
      let finished = false;
      try {
        const send = (extra) => fetch(CONFIG.supabaseUrl + '/rest/v1/rpc/harpatka_signup', {
          method: 'POST',
          headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey, 'Content-Type': 'application/json' },
          body: JSON.stringify(Object.assign({ p_name: name, p_phone: norm, p_age: age, p_gender: gender }, extra))
        });
        let res = await send(PAID ? { p_src: 'p' } : {});
        if (!res.ok && PAID) res = await send({});   // אם הפונקציה בבסיס הנתונים עוד לא עודכנה (admin/source.sql): ההרשמה נשמרת בלי הסימון
        const out = res.ok ? await res.json() : null;
        if (out === 'created' || out === 'exists') {   // כפילות: אותה הודעה, בלי לחשוף שהמספר כבר רשום
          if (out === 'created') leadOnce();   // Lead רק על מספר חדש (חד ערכי), לא על כפילות
          finished = true; allDone();
        } else if (out === 'invalid_phone') setErr(phoneI, q('phoneErr'), 'מספר הטלפון לא תקין');
        else if (out === 'invalid_name') setErr(nameI, q('nameErr'), 'נא למלא שם');
        else if (out === 'invalid_age') setErr(ageI, q('ageErr'), 'נא למלא גיל תקין');
        else throw new Error('signup failed');
      } catch (err) {
        q('fail').innerHTML = 'משהו השתבש, אפשר ליצור קשר ישירות: <a href="#" class="underline font-bold">שיחה בוואטסאפ</a>';
        q('fail').querySelector('a').addEventListener('click', ev => { ev.preventDefault(); const m = document.getElementById('contactModal'); if (m) { if (m.hidden) openModal(m); showChoose(); } });
      }
      if (!finished) { btn.disabled = false; btn.textContent = 'שמירת מקום'; }
    });
  }
  /* פופאפ יצירת קשר: כפתור שלישי "השאירו פרטים" מחליף את הבחירה בטופס (באותו פופאפ) */
  const cmChoose = document.getElementById('cmChoose'), cmFormView = document.getElementById('cmFormView');
  function showChoose() { if (!cmChoose) return; cmFormView.hidden = true; cmChoose.hidden = false; }
  function showForm() { if (!cmChoose) return; cmChoose.hidden = true; cmFormView.hidden = false; }
  document.querySelectorAll('[data-su-root]').forEach(initSignup);
  if (cmChoose) {
    document.getElementById('cmShowForm').addEventListener('click', () => { showForm(); const i = cmFormView.querySelector('[data-su="name"]'); if (i) i.focus(); });
    document.getElementById('cmBack').addEventListener('click', showChoose);
    new MutationObserver(() => { if (document.getElementById('contactModal').hidden) showForm(); }).observe(document.getElementById('contactModal'), { attributes: true, attributeFilter: ['hidden'] });
  }

  ['updates'].forEach(id => {
    const el = document.getElementById(id);
    if (el) { el.setAttribute('href', CONFIG.updatesGroupLink); el.setAttribute('target', '_blank'); el.setAttribute('rel', 'noopener'); }
  });

  /* ===== CTA ראשי: פותח פופאפ בחירה בין הדר לאופיר; גם כפתורי המנחים בכרטיסים פותחים שיחת וואטסאפ ישירה =====
     אירוע ההמרה Lead של ה-Pixel נשלח בלחיצה על וואטסאפ של אחד מהם */
  const waLink = (num, msg) => 'https://wa.me/' + num + '?text=' + encodeURIComponent(msg);
  const waLinks = { hadar: waLink(CONFIG.whatsappHadar, CONFIG.hadarMessage), ofir: waLink(CONFIG.whatsappOfir, CONFIG.ofirMessage) };
  document.querySelectorAll('[data-wa]').forEach(el => {
    el.setAttribute('href', waLinks[el.dataset.wa]);
  });
  const contactModal = document.getElementById('contactModal');
  document.querySelectorAll('[data-contact]').forEach(el => {
    el.setAttribute('href', '#');
    el.addEventListener('click', (e) => { e.preventDefault(); if (contactModal) openModal(contactModal); });
  });

  /* ===== מחיר בכפתור התשלום (בהודעת התודה): 100 ₪ ב-3 הימים האחרונים לפני המפגש הקרוב, אחרת 80 ₪ ===== */
  (async () => {
    let m = { date: '2026-10-25' };
    try {
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
      const r = await fetch(CONFIG.supabaseUrl + '/rest/v1/harpatka_meetings?select=meeting_date&meeting_date=gte.' + today + '&order=meeting_date.asc&limit=1',
        { headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey } });
      const rows = r.ok ? await r.json() : [];
      if (rows && rows[0]) m = { date: rows[0].meeting_date };
    } catch (e) {}
    const day = s => { const [y, mm, d] = s.split('-').map(Number); return Date.UTC(y, mm - 1, d) / 864e5; };
    const left = day(m.date) - day(new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date()));
    const price = left <= 3 ? '100' : '80';
    document.querySelectorAll('[data-price]').forEach(e => { e.textContent = price + ' ₪'; });
  })();
})();
