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
          <div class="su-fold"><div>
            <h2 class="su-title">יוצאים להרפתקה</h2>
            <div class="mt-badge" role="note"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg><b data-meeting-when>המפגש הקרוב</b></div>
          </div></div>
          <form data-su="form" novalidate class="text-start">
            <input type="text" name="website" data-su="hp" class="su-hp" tabindex="-1" autocomplete="off" aria-hidden="true">
            <div class="su-fold"><div>
              <div class="su-grid">
                <div class="su-cell su-wide">
                  <div class="su-names">
                    <input id="cmFirst" data-autofocus data-su="first" name="first" type="text" class="su-input" autocomplete="given-name" maxlength="40" placeholder="שם פרטי" aria-label="שם פרטי" required>
                    <input id="cmLast" data-su="last" name="last" type="text" class="su-input" autocomplete="family-name" maxlength="40" placeholder="שם משפחה" aria-label="שם משפחה" required>
                  </div>
                  <div data-su="nameErr" class="su-err" role="alert"></div>
                </div>
                <div class="su-cell">
                  <input id="cmPhone" data-su="phone" name="phone" type="tel" dir="ltr" inputmode="tel" class="su-input text-end" autocomplete="tel" maxlength="24" placeholder="טלפון" aria-label="טלפון" required>
                  <div data-su="phoneErr" class="su-err" role="alert"></div>
                </div>
                <div class="su-cell">
                  <input id="cmAge" data-su="age" name="age" type="number" inputmode="numeric" min="18" max="99" class="su-input" autocomplete="off" placeholder="גיל" aria-label="גיל" required>
                  <div data-su="ageErr" class="su-err" role="alert"></div>
                </div>
                <div class="su-cell su-wide">
                  <div class="su-seg eq" data-su="gender" role="radiogroup" aria-label="מגדר">
                    <label><input type="radio" name="cmGender" value="male"><span>גבר</span></label>
                    <label><input type="radio" name="cmGender" value="female"><span>אישה</span></label>
                  </div>
                  <div data-su="genderErr" class="su-err" role="alert"></div>
                </div>
              </div>
            </div></div>
            <button data-su="btn" type="submit" class="btn-primary rounded-full px-5 md:px-8 py-3.5 text-[1.2rem] whitespace-nowrap w-full mt-4">הרשמה</button>
            <div data-su="fail" class="su-err mt-3 text-center" role="alert"></div>
            <div class="su-fold su-after shut" data-su="after"><div>
              <p class="su-paynote">ההרשמה תושלם רק לאחר תשלום <span data-price>80 ₪</span> בפייבוקס</p>
              <a href="#" target="_blank" rel="noopener" data-paybox class="btn-primary rounded-full px-8 py-4 text-[1.2rem] block text-center w-full">לתשלום <span data-price>80 ₪</span> בפייבוקס</a>
            </div></div>
          </form>
        </div>
      </div>
    </div>
  </div>`.replace(/__BASE__/g, BASE);
  /* v7: מגדר כרשימה נפתחת רגילה במקום שני כפתורים (ברירת מחדל לכל העמודים; window.REGISTER_GENDER = 'buttons' מחזיר את הכפתורים) */
  const GENDER_SELECT = '<select data-su="gender" name="cmGender" class="su-input su-select" aria-label="מגדר" required><option value="" selected disabled>מגדר</option><option value="male">גבר</option><option value="female">אישה</option></select>';
  const MODAL_FINAL = window.REGISTER_GENDER !== 'buttons'
    ? MODAL_HTML.replace(/<div class="su-seg eq" data-su="gender"[\s\S]*?<\/div>(?=\s*<div data-su="genderErr")/, GENDER_SELECT)
    : MODAL_HTML;
  if (window.REGISTER_MIN !== false) document.documentElement.classList.add('reg-min');
  document.body.insertAdjacentHTML('beforeend', MODAL_FINAL);

  /* ===== מנגנון פופאפ כללי (משותף לכל ה-.modal) ===== */
  let modalLastFocus = null, urlBeforeReg = null;
  /* כשטופס ההרשמה פתוח, כתובת העמוד הופכת ל-/register/ (אפשר להעתיק ולשלוח); בסגירה היא חוזרת למה שהייתה */
  function regUrl(open) {
    try {
      if (open) {
        if (/\/register\/?$/.test(location.pathname) || urlBeforeReg) return;
        const sp = new URLSearchParams(location.search); sp.delete('register');   // ?register=1 הוא רק מנגנון הפתיחה
        const qs = sp.toString() ? '?' + sp.toString() : '';
        urlBeforeReg = location.pathname + qs + location.hash;
        history.replaceState(history.state, '', BASE + 'register/' + qs);
      } else if (urlBeforeReg) { history.replaceState(history.state, '', urlBeforeReg); urlBeforeReg = null; }
    } catch (e) {}
  }
  /* נעילת גלילת הדף מאחורי הפופאפ (גם במובייל); הפופאפ עצמו נגלל, למשל כשהמקלדת פתוחה */
  let locked = false;
  /* נעילת גלילת הדף כשהפופאפ פתוח: הגוף מקובע במקומו (position: fixed עם היסט הגלילה), כך שגם הזזת הדף על ידי המקלדת או גרירה על הרקע לא גוללת את הדף מאחור; בסגירה הגלילה חוזרת למקום */
  let lockY = 0;
  function lockPage(){
    if (locked) return;
    locked = true; lockY = window.scrollY || document.documentElement.scrollTop || 0;
    document.body.style.top = (-lockY) + 'px'; document.documentElement.classList.add('modal-lock');
  }
  function unlockPage(){
    if (!locked) return;
    locked = false; document.documentElement.classList.remove('modal-lock'); document.body.style.top = '';
    window.scrollTo({ top: lockY, left: 0, behavior: 'instant' });
  }
  function openModal(m, noFocus){
    if (m.id === 'contactModal') { regUrl(true); modalHistPush(); }
    modalLastFocus = document.activeElement;
    m.hidden = false;
    requestAnimationFrame(() => m.classList.add('open'));
    lockPage();
    /* הפוקוס עובר לקופסת הפופאפ (בלי טבעת פוקוס מכוערת על כפתור הסגירה) */
    /* פתיחה על ידי המשתמש (לחיצה על כפתור): הפוקוס עובר לשדה השם והמקלדת עולה. בכניסה ישירה ל-/register/ בלי פוקוס אוטומטי */
    const f = (!noFocus && m.querySelector('[data-autofocus]')) || m.querySelector('.modal-box');
    if (f) {
      if (f.matches('.modal-box')) f.setAttribute('tabindex', '-1');
      /* שדה השם מקבל פוקוס רק אחרי שהמגירה סיימה לרדת: אם המקלדת עולה בזמן שהטופס עוד מחוץ למסך, הדפדפן (אנדרואיד) מזיז את הדף והחלק העליון נחתך. ב-iOS חייבים מיד (בתוך הלחיצה) */
      const ios = /iP(hone|ad|od)/.test(navigator.userAgent);
      if (f.matches('input, select, textarea') && !ios) setTimeout(() => { if (!m.hidden && m.classList.contains('open')) f.focus({ preventScroll: true }); }, 420);
      else f.focus({ preventScroll: true });
    }
  }
  /* החלקה למעלה בפס שבתחתית סוגרת (אותו מנגנון כמו המגירות בדף הניהול, הפוך: נפתח מלמעלה) */
  function bindGrab(m){
    const box = m.querySelector('.modal-box'); if (!box) return;
    const g = document.createElement('div'); g.className = 'modal-grab'; g.setAttribute('aria-hidden', 'true'); g.innerHTML = '<i></i>';
    box.appendChild(g);
    let sy = 0, dy = 0, t0 = 0, drag = false;
    g.addEventListener('pointerdown', (e) => {
      if (e.button > 0) return; drag = true; sy = e.clientY; dy = 0; t0 = performance.now();
      box.style.transition = 'none'; try { g.setPointerCapture(e.pointerId); } catch (x) {}
    });
    g.addEventListener('pointermove', (e) => { if (!drag) return; dy = Math.max(0, sy - e.clientY); box.style.transform = 'translateY(' + (-dy) + 'px)'; });
    const end = () => {
      if (!drag) return; drag = false;
      const v = dy / Math.max(1, performance.now() - t0), tap = dy < 4;
      box.style.transition = '';
      if (tap || dy > 90 || (v > 0.6 && dy > 30)) { box.style.transform = 'translateY(-110%)'; closeModal(m); setTimeout(() => { box.style.transform = ''; }, 400); }
      else box.style.transform = '';
    };
    g.addEventListener('pointerup', end); g.addEventListener('pointercancel', end);
  }
  /* כפתור "חזרה" של הדפדפן (ובאנדרואיד) כשפופאפ ההרשמה פתוח סוגר את הפופאפ ולא עוזב את העמוד: בפתיחה נוספת רשומת היסטוריה אחת,
     חזרה בדפדפן (popstate) סוגרת את הפופאפ, וסגירה אחרת (X, רקע, Esc, החלקה) חוזרת אחורה ברשומה שהוספנו */
  let modalHist = false, skipPop = false;
  function modalHistPush() {
    if (modalHist) return;
    try { history.pushState({ harpatkaModal: 1 }, '', location.href); modalHist = true; } catch (e) {}
  }
  window.addEventListener('popstate', () => {
    if (skipPop) { skipPop = false; modalHist = false; regUrl(false); return; }
    const open = document.querySelector('#contactModal.open');
    if (open && modalHist) { modalHist = false; closeModal(open, true); }
  });
  function closeModal(m, fromPop){
    if (m.id === 'contactModal') {
      if (modalHist && !fromPop) { skipPop = true; try { history.back(); } catch (e) { skipPop = false; modalHist = false; regUrl(false); } }
      else regUrl(false);
    }
    m.classList.remove('open');
    setTimeout(() => { m.hidden = true; if (!document.querySelector('.modal:not([hidden])')) unlockPage(); }, 360);
    if (modalLastFocus) modalLastFocus.focus();
  }
  // כל פופאפ נסגר ב-X, בלחיצה על הרקע, וב-Esc
  document.querySelectorAll('.modal').forEach(m => {
    m.querySelectorAll('[data-close-modal]').forEach(b => b.addEventListener('click', () => closeModal(m)));
    m.addEventListener('click', (e) => { if (e.target === m) closeModal(m); });
    bindGrab(m);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const open = document.querySelector('.modal.open');
    if (open) closeModal(open);
  });

  /* ===== הצטרפות לעדכונים — קישור ישיר לקבוצת הוואטסאפ (עד גיל 50), בלי פופאפ בחירה ===== */
  document.querySelectorAll('[data-updates]').forEach(el => {
    el.setAttribute('href', CONFIG.updatesGroupLink);
    /* JoinGroup ל-Pixel בלחיצה על הצטרפות לקבוצה: ערך 1, פעם אחת בלבד לכל מכשיר */
    el.addEventListener('click', () => {
      if (!window.fbq) return;
      const K = 'harpatka_join_sent';
      try { if (localStorage.getItem(K)) return; localStorage.setItem(K, '1'); } catch (e) {}
      try { fbq('trackCustom', 'JoinGroup', { value: 1, currency: 'ILS' }); } catch (e) {}
    });
  });
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
    const firstI = q('first'), lastI = q('last'), phoneI = q('phone'), ageI = q('age'), btn = q('btn'), t0 = Date.now();
    const setErr = (input, errEl, msg) => { errEl.textContent = msg || ''; input.classList.toggle('bad', !!msg); };
    /* אחרי הרשמה: התוכן נסגר מלמעלה, הכפתור מתחלף ל"נשמר זמנית" ואז נחשפים הטקסט וכפתור התשלום בפייבוקס (הכול באנימציה) */
    let saved = false;
    const showDone = (payOk = true) => {
      if (saved) return; saved = true;
      root.querySelectorAll('.su-fold:not(.su-after)').forEach(f => f.classList.add('shut'));
      btn.disabled = true; btn.classList.add('swap');
      setTimeout(() => { btn.textContent = payOk ? 'נשמר זמנית' : 'הפרטים נשלחו'; btn.classList.remove('swap'); btn.classList.add('saved'); }, 260);
      if (payOk) setTimeout(() => { const a = q('after'); if (a) a.classList.remove('shut'); }, 700);
    };
    suRoots.push(showDone);
    const clrName = () => { q('nameErr').textContent = ''; firstI.classList.remove('bad'); lastI.classList.remove('bad'); };
    firstI.addEventListener('input', clrName); lastI.addEventListener('input', clrName);
    phoneI.addEventListener('input', () => setErr(phoneI, q('phoneErr'), ''));
    ageI.addEventListener('input', () => setErr(ageI, q('ageErr'), ''));
    const genderBox = q('gender');
    genderBox.addEventListener('change', () => { genderBox.classList.remove('bad'); q('genderErr').textContent = ''; });
    form.addEventListener('submit', async (e) => {
      e.preventDefault(); q('fail').textContent = '';
      const first = firstI.value.trim().replace(/\s+/g, ' '), last = lastI.value.trim().replace(/\s+/g, ' '), norm = normPhone(phoneI.value);
      let ok = true;
      if (first.length < 2 || last.length < 2) { q('nameErr').textContent = 'נא למלא שם פרטי ושם משפחה'; firstI.classList.toggle('bad', first.length < 2); lastI.classList.toggle('bad', last.length < 2); ok = false; }
      if (!norm) { setErr(phoneI, q('phoneErr'), 'מספר לא תקין'); ok = false; }
      const age = parseInt(ageI.value, 10);
      if (!(age >= 18 && age <= 99)) { setErr(ageI, q('ageErr'), 'גיל לא תקין'); ok = false; }
      const gEl = genderBox.matches('select') ? genderBox : genderBox.querySelector('input:checked'), gender = gEl && gEl.value ? gEl.value : null;
      if (!gender) { genderBox.classList.add('bad'); q('genderErr').textContent = 'נא לבחור'; ok = false; }
      if (!ok) return;
      /* אפשרות תשלום רק בטווח הגילאים שמתאים למפגש: גברים 40 עד 55, נשים 35 עד 50 (ההרשמה עצמה נשמרת תמיד) */
      /* תשלום רק אחרי הרשמה למפגש: בלי מפגש (השארת פרטים בלבד) אין כפתור תשלום */
      const payOk = (gender === 'male' ? (age >= 40 && age <= 55) : (age >= 35 && age <= 50)) && !!(selMeeting || nearest);
      const allDone = () => { suRoots.forEach(f => f(payOk)); };   // בלי שמירה בדפדפן: בכל טעינה של הדף הטופס מוצג מחדש
      if (q('hp').value || Date.now() - t0 < 1500) { allDone(); return; }   // בוט: מציגים הצלחה בלי לשמור
      btn.disabled = true; btn.textContent = 'שולחים...';
      let finished = false;
      try {
        const send = (extra) => fetch(CONFIG.supabaseUrl + '/rest/v1/rpc/harpatka_signup', {
          method: 'POST',
          headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey, 'Content-Type': 'application/json' },
          body: JSON.stringify(Object.assign({ p_first: first, p_last: last, p_phone: norm, p_age: age, p_gender: gender }, selMeeting && selMeeting.id ? { p_meeting: selMeeting.id } : {}, extra))
        });
        let res = await send(PAID ? { p_src: 'p' } : {});
        if (!res.ok && PAID) res = await send({});   // אם הפונקציה בבסיס הנתונים עוד לא עודכנה (admin/source.sql): ההרשמה נשמרת בלי הסימון
        const out = res.ok ? await res.json() : null;
        if (out === 'created' || out === 'exists') {   // כפילות: אותה הודעה, בלי לחשוף שהמספר כבר רשום
          if (out === 'created') {   // Lead רק על מספר חדש (חד ערכי), לא על כפילות
            leadOnce();
            /* RegistrationValue: ערך 3 למי שבטווח (נשים 35 עד 50, גברים 40 עד 55, זהה ל-payOk), 1 למי שמחוץ לטווח */
            const inRange = gender === 'male' ? (age >= 40 && age <= 55) : (age >= 35 && age <= 50);
            try { if (window.fbq) fbq('trackCustom', 'RegistrationValue', { value: inRange ? 3 : 1, currency: 'ILS' }); } catch (e) {}
          }
          finished = true; allDone();
        } else if (out === 'invalid_phone') setErr(phoneI, q('phoneErr'), 'מספר לא תקין');
        else if (out === 'invalid_name') q('nameErr').textContent = 'נא למלא שם פרטי ושם משפחה';
        else if (out === 'invalid_age') setErr(ageI, q('ageErr'), 'גיל לא תקין');
        else if (out === 'invalid_gender') { genderBox.classList.add('bad'); q('genderErr').textContent = 'נא לבחור'; }
        else throw new Error('signup failed');
      } catch (err) {
        q('fail').innerHTML = 'משהו השתבש, אפשר ליצור קשר ישירות: <a href="#" class="underline font-bold">שיחה בוואטסאפ</a>';
        q('fail').querySelector('a').addEventListener('click', ev => { ev.preventDefault(); const m = document.getElementById('contactModal'); if (m) { if (m.hidden) openModal(m); showChoose(); } });
      }
      if (!finished) { btn.disabled = false; btn.textContent = submitLabel; }
    });
  }
  /* פופאפ יצירת קשר: כפתור שלישי "השאירו פרטים" מחליף את הבחירה בטופס (באותו פופאפ) */
  const cmChoose = document.getElementById('cmChoose'), cmFormView = document.getElementById('cmFormView');
  function showChoose() { if (!cmChoose) return; cmFormView.hidden = true; cmChoose.hidden = false; }
  function showForm() { if (!cmChoose) return; cmChoose.hidden = true; cmFormView.hidden = false; }
  document.querySelectorAll('[data-su-root]').forEach(initSignup);
  if (cmChoose) {
    document.getElementById('cmShowForm').addEventListener('click', () => { showForm(); const i = cmFormView.querySelector('[data-su="first"]'); if (i) i.focus(); });
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
  window.HarpatkaRegister = { open: (auto, meeting) => { selMeeting = meeting && meeting.id ? meeting : null; showMeeting(selMeeting || nearest); if (contactModal) openModal(contactModal, auto === true); } };   // לשימוש עמודים אחרים
  if (new URLSearchParams(location.search).has('register')) setTimeout(() => window.HarpatkaRegister.open(true), 500);   // הגעה דרך /register/: דף הבית נטען והפופאפ נפתח עליו
  document.querySelectorAll('[data-contact]').forEach(el => {
    el.setAttribute('href', '#');
    el.addEventListener('click', (e) => { e.preventDefault(); window.HarpatkaRegister.open(false, el.__meeting); });
    if (el.getAttribute('role') === 'button') el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); window.HarpatkaRegister.open(false, el.__meeting); } });   // אלמנט שאינו קישור (למשל הבאנר העליון) נגיש גם במקלדת
  });

  /* ===== המפגש שנבחר להרשמה (ברירת מחדל: הקרוב) ומחיר בכפתור התשלום לפי מדרגות המחיר (harpatka_price_tiers; בלי מדרגות: 100 ₪ ב-3 הימים האחרונים, אחרת 80 ₪) ===== */
  const HE_DAYS = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  const dayN = (s) => { const [y, mm, d] = s.split('-').map(Number); return Date.UTC(y, mm - 1, d) / 864e5; };
  const todayIL = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
  /* ברירת המחדל מהקוד רק אם היא עוד לא עברה (ורק עד שהמפגש האמיתי מבסיס הנתונים נטען); בלי מפגש עתידי הפופאפ לא משויך לשום מפגש */
  let selMeeting = null, nearest = (CONFIG.meetingFallback || { date: '2026-10-25', time: '20:00' }).date >= todayIL ? (CONFIG.meetingFallback || { date: '2026-10-25', time: '20:00' }) : null;
  /* מחיר לפי מדרגות המחיר של המפגש עצמו (T = { base, steps: [{ days, price }] }): המדרגה שמתחילה הכי קרוב למפגש מבין אלה שכבר התחילו, אחרת המחיר הרגיל. בלי מדרגות: 100 ₪ ב-3 הימים האחרונים, אחרת 80 ₪ */
  const normT = (t) => (t && !Array.isArray(t) && Number.isFinite(Number(t.base))) ? { base: Number(t.base), steps: (Array.isArray(t.steps) ? t.steps : []).map((x) => ({ days: Number(x.days), price: Number(x.price) })).filter((x) => x.days >= 1 && Number.isFinite(x.price)) } : null;
  const priceFor = (left, T) => {
    if (T) {
      const s = T.steps.filter((x) => left <= x.days).sort((a, b) => a.days - b.days)[0];
      return String(s ? s.price : T.base);
    }
    return left <= 3 ? '100' : '80';
  };
  /* טקסט כפתור השליחה: "הרשמה" כשיש מפגש להירשם אליו, "השארת פרטים" כשאין (כמו הכפתור הראשי בעמוד) */
  let submitLabel = 'הרשמה';
  const setSubmitLabel = (m) => { submitLabel = m ? 'הרשמה' : 'השארת פרטים'; document.querySelectorAll('[data-su="btn"]:not(.saved):not(:disabled)').forEach((b) => { b.textContent = submitLabel; }); };
  const showMeeting = (m) => {
    setSubmitLabel(m);
    document.querySelectorAll('.mt-badge').forEach((e) => { e.hidden = !m; });   // אין מפגש: אין שורת תאריך בכותרת
    if (!m) { document.querySelectorAll('[data-price]').forEach((e) => { e.textContent = priceFor(999, null) + ' ₪'; }); return; }
    const [, mo, d] = m.date.split('-').map(Number), wd = HE_DAYS[new Date(m.date + 'T12:00:00Z').getUTCDay()];
    const when = 'יום ' + wd + ' ' + Number(d) + '.' + Number(mo) + (m.time ? ' · ' + m.time : '');
    document.querySelectorAll('[data-meeting-when]').forEach((e) => { e.textContent = when; });
    document.querySelectorAll('[data-meeting-place]').forEach((e) => { e.textContent = CONFIG.meetingPlace || ''; });
    const left = dayN(m.date) - dayN(new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date()));
    const price = priceFor(left, m.tiers);
    document.querySelectorAll('[data-price]').forEach((e) => { e.textContent = price + ' ₪'; });
  };
  showMeeting(nearest);   // מיד, בלי להמתין לרשת
  (async () => {
    const H = { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey };
    try {
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
      const r = await fetch(CONFIG.supabaseUrl + '/rest/v1/harpatka_meetings?select=id,meeting_date,meeting_time,price_tiers&meeting_date=gte.' + today + '&order=meeting_date.asc,meeting_time.asc&limit=1', { headers: H });
      const rows = r.ok ? await r.json() : [];
      if (r.ok && !(rows && rows[0])) nearest = null;   // אין מפגש עתידי
      if (rows && rows[0]) nearest = { id: rows[0].id, date: rows[0].meeting_date, time: String(rows[0].meeting_time).slice(0, 5), tiers: normT(rows[0].price_tiers) };
      showMeeting(selMeeting || nearest);
    } catch (e) {}
  })();
})();
