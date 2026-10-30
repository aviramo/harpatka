/* פופאפ הרשמה משותף (עמוד הבית, v6, ביודנסה).
 * מזריק את הפופאפ לעמוד, מחבר את כפתורי ה-CTA (data-contact), הטופס (Supabase), התשלום והוואטסאפ.
 * דורש: shared/config.js (CONFIG) ו-shared/register.css. נטען בסוף ה-body.
 * הכפתור בעמוד רק צריך data-contact. אין להעתיק את הקוד הזה לעמודים. */
(function () {
  const BASE = document.currentScript.src.replace(/shared\/register\.js.*$/, '');   // כתובת השורש של האתר (גם מתוך תיקיות משנה)
  /* טווח הגילאים: מ-shared/age.js (AGE_MIN, AGE_MAX). עמוד שלא טען אותו מקבל אותו כאן */
  if (window.AGE_MIN == null) { const s = document.createElement('script'); s.src = BASE + 'shared/age.js?v=20261031a'; document.head.appendChild(s); }
  const ageOk = (a) => window.AGE_MIN != null && Number(a) >= window.AGE_MIN && Number(a) <= window.AGE_MAX;
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
            <h2 class="su-title" data-meeting-name hidden></h2>
            <div class="mt-badge" role="note"><b data-meeting-when>המפגש הקרוב</b></div>
          </div></div>
          <form data-su="form" novalidate class="text-start">
            <input type="text" name="website" data-su="hp" class="su-hp" tabindex="-1" autocomplete="off" aria-hidden="true">
            <div class="su-fold"><div>
              <div class="su-grid">
                <div class="su-cell">${PersonForm.html('first', { id: 'cmFirst', cls: 'su-input', autofocus: true })}</div>
                <div class="su-cell">${PersonForm.html('last', { id: 'cmLast', cls: 'su-input' })}</div>
                <div class="su-cell su-wide">${PersonForm.err('name', 'su-err')}</div>
                <div class="su-cell">
                  ${PersonForm.html('phone', { id: 'cmPhone', cls: 'su-input text-end' })}
                  ${PersonForm.err('phone', 'su-err')}
                </div>
                <div class="su-cell su-ag">
                  <div class="su-cell">
                    ${PersonForm.html('age', { id: 'cmAge', cls: 'su-input' })}
                    ${PersonForm.err('age', 'su-err')}
                  </div>
                  <div class="su-cell">
                    ${PersonForm.html('gender', { id: 'cmGender', cls: 'su-input su-select' })}
                    ${PersonForm.err('gender', 'su-err')}
                  </div>
                </div>
              </div>
              <p class="su-phonehint" data-su="phonehint">החשבון שלכם עוד לא מחובר למשתתף אצלנו. הזינו את הטלפון שבו נרשמתם, ונחבר אליו את החשבון</p>
              <div class="su-member" data-su="member"><p class="su-memberp">הפרטים שלכם כבר שמורים אצלנו</p><p class="su-who" data-su="who"></p></div>
              <a href="__BASE__me/?login=1&back=reg" class="su-glink" data-su="glink">נרשמתם בעבר? לחצו כאן</a>
            </div></div>
            <button data-su="btn" type="submit" class="btn-primary rounded-full px-5 md:px-8 py-3.5 text-[1.2rem] whitespace-nowrap w-full mt-4">הרשמה</button>
            <div data-su="fail" class="su-err mt-3 text-center" role="alert"></div>
            <div class="su-fold su-after shut" data-su="after"><div>
              <p class="su-paynote">המקום נשמר באופן זמני, והוא יישמר קבוע רק לאחר תשלום</p>
              <div class="su-payfold" data-su="payfold"><div>
                <a href="#" target="_blank" rel="noopener" data-paybox class="btn-primary rounded-full px-8 py-4 text-[1.2rem] block text-center w-full">לתשלום <span data-price>80 ₪</span> בפייבוקס</a>
                <div class="su-paylinks" data-su="paylinks"><button type="button" class="su-lnk" data-su="other">רוצים לשלם בדרך אחרת?</button></div>
              </div></div>
              <div class="su-reported" data-su="reported" hidden>התשלום ממתין לאישור שלנו</div>
            </div></div>
          </form>
        </div>
      </div>
    </div>
  </div>`.replace(/__BASE__/g, BASE);
  if (window.REGISTER_MIN !== false) document.documentElement.classList.add('reg-min');
  /* שאלת יציאה מהחשבון: אותה מעטפת פופאפ של ההרשמה (נפתח מלמעלה, פס סגירה בתחתית) */
  const LOGOUT_HTML = `<div id="logoutModal" class="modal" hidden role="dialog" aria-modal="true" aria-labelledby="logoutTtl"><div class="modal-box"><button type="button" class="modal-close" data-close-modal aria-label="סגירה">&times;</button><p class="su-lgwho" id="logoutTtl"></p><a class="su-lgyes" href="__BASE__me/">כניסה לאזור האישי</a><button type="button" class="su-lgno" data-lg="yes">יציאה מהחשבון</button></div></div>`.replace(/__BASE__/g, BASE);
  const OTHER_HTML = `<div id="otherModal" class="modal" hidden role="dialog" aria-modal="true" aria-labelledby="otherTtl"><div class="modal-box"><button type="button" class="modal-close" data-close-modal aria-label="סגירה">&times;</button><p class="su-lgwho" id="otherTtl">לשלם בדרך אחרת</p><p class="su-lgq">נפתחת שיחת וואטסאפ עם אחד המנהלים, וההודעה כבר מוכנה:</p><p class="su-lginfo" id="otherInfo"></p><a class="wacard" id="otherHadar" target="_blank" rel="noopener"><img src="__BASE__images/hadar.jpg" width="52" height="52" alt=""><span class="wat"><b>הדר לוריא</b><small>שיחה בוואטסאפ</small></span><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.5 14.4c-.3-.1-1.7-.8-2-.9-.3-.1-.5-.1-.7.1-.2.3-.8.9-.9 1.1-.2.2-.3.2-.6.1-.3-.1-1.2-.5-2.3-1.4-.9-.8-1.4-1.7-1.6-2-.2-.3 0-.4.1-.6l.4-.5c.1-.2.2-.3.3-.5.1-.2 0-.4 0-.5l-.9-2.2c-.2-.6-.5-.5-.7-.5h-.6c-.2 0-.5.1-.8.4-.3.3-1 1-1 2.4s1 2.8 1.2 3c.1.2 2 3.1 4.9 4.3.7.3 1.2.5 1.6.6.7.2 1.3.2 1.8.1.6-.1 1.7-.7 1.9-1.4.2-.7.2-1.2.2-1.4-.1-.1-.3-.2-.6-.3zM12 21.5c-1.7 0-3.4-.5-4.8-1.3l-.3-.2-3.6.9 1-3.5-.2-.4C3.2 15.6 2.7 13.8 2.7 12c0-5.1 4.2-9.3 9.3-9.3 2.5 0 4.8 1 6.6 2.7 1.8 1.8 2.7 4.1 2.7 6.6 0 5.2-4.2 9.5-9.3 9.5zM20 4C17.9 1.8 15 .7 12 .7 5.8.7.7 5.8.7 12c0 2 .5 3.9 1.5 5.6L.6 23.4l6-1.6c1.6.9 3.5 1.4 5.4 1.4 6.2 0 11.3-5.1 11.3-11.3 0-3-1.2-5.8-3.3-7.9z"/></svg></a><a class="wacard" id="otherOfir" target="_blank" rel="noopener"><img src="__BASE__images/ofir-v3.jpg" width="52" height="52" alt=""><span class="wat"><b>אופיר אבירם</b><small>שיחה בוואטסאפ</small></span><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.5 14.4c-.3-.1-1.7-.8-2-.9-.3-.1-.5-.1-.7.1-.2.3-.8.9-.9 1.1-.2.2-.3.2-.6.1-.3-.1-1.2-.5-2.3-1.4-.9-.8-1.4-1.7-1.6-2-.2-.3 0-.4.1-.6l.4-.5c.1-.2.2-.3.3-.5.1-.2 0-.4 0-.5l-.9-2.2c-.2-.6-.5-.5-.7-.5h-.6c-.2 0-.5.1-.8.4-.3.3-1 1-1 2.4s1 2.8 1.2 3c.1.2 2 3.1 4.9 4.3.7.3 1.2.5 1.6.6.7.2 1.3.2 1.8.1.6-.1 1.7-.7 1.9-1.4.2-.7.2-1.2.2-1.4-.1-.1-.3-.2-.6-.3zM12 21.5c-1.7 0-3.4-.5-4.8-1.3l-.3-.2-3.6.9 1-3.5-.2-.4C3.2 15.6 2.7 13.8 2.7 12c0-5.1 4.2-9.3 9.3-9.3 2.5 0 4.8 1 6.6 2.7 1.8 1.8 2.7 4.1 2.7 6.6 0 5.2-4.2 9.5-9.3 9.5zM20 4C17.9 1.8 15 .7 12 .7 5.8.7.7 5.8.7 12c0 2 .5 3.9 1.5 5.6L.6 23.4l6-1.6c1.6.9 3.5 1.4 5.4 1.4 6.2 0 11.3-5.1 11.3-11.3 0-3-1.2-5.8-3.3-7.9z"/></svg></a></div></div>`.replace(/__BASE__/g, BASE);
  document.body.insertAdjacentHTML('beforeend', MODAL_HTML + LOGOUT_HTML + OTHER_HTML);

  /* ===== מנגנון פופאפ כללי (משותף לכל ה-.modal) ===== */
  let modalLastFocus = null, urlBeforeReg = null;
  /* הכתובת בדפדפן לא משתנה כשהפופאפ פתוח (בוטל ה-/register/ בכתובת, 28.10.26); regUrl נשארה כפונקציה ריקה כדי שהקריאות אליה ימשיכו לעבוד */
  function regUrl() {}
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
  const normPhone = PersonForm.normPhone;   // הלוגיקה בטופס המשותף (shared/person-form.js)
  window.normPhone = normPhone;
  const suRoots = [];
  function initSignup(root) {
    const q = k => root.querySelector('[data-su="' + k + '"]');
    const form = q('form'); if (!form) return;
    const btn = q('btn'), t0 = Date.now();
    PersonForm.bind(root);
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
    /* לחיצה על התשלום בפייבוקס = דיווח על תשלום, אוטומטית (בלי קישור "שילמתי"): פייבוקס נפתח בלשונית חדשה, ובמערכת המפגש מסומן "דווח" ומחכה לאימות שלנו */
    const payA = root.querySelector('[data-paybox]');
    let reporting = false;
    const reportPay = async () => {
      const m = selMeeting || nearest; if (!m || !m.id || reporting) return;
      let tk = null; try { tk = localStorage.getItem('harpatka_claim_token'); } catch (e) {}
      if (!meInfo && !tk) return;   // דיווח דורש חשבון מחובר (או צפייה כמשתתף) או אסימון מהרשמה שהרגע נעשתה
      reporting = true;
      const ob = meInfo ? meOptimistic(m.id, { reported: true, rejected: false }) : null;
      try {
        let r;
        if (meInfo) r = await meRpc('harpatka_me_report_payment', { p_meeting: m.id });
        else {
          const res = await fetch(CONFIG.supabaseUrl + '/rest/v1/rpc/harpatka_report_payment_token', { method: 'POST', keepalive: true, headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_token: tk, p_meeting: m.id }) });
          if (!res.ok) throw new Error('HTTP ' + res.status); r = await res.json();
        }
        if (r !== 'ok' && r !== 'reported' && r !== 'already') throw new Error('report failed');
        if (ob) ob.done();
        const fold = q('payfold'), done = q('reported');
        if (fold) { fold.classList.add('closing'); setTimeout(() => { fold.hidden = true; if (done) done.hidden = false; }, matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 420); } else if (done) done.hidden = false;
        if (meInfo) meLoader.reload(0);
      } catch (e) { if (ob) ob.fail(); }   // הדיווח נכשל: הכפתור נשאר, ולחיצה נוספת מנסה שוב
      reporting = false;
    };
    if (payA) payA.addEventListener('click', () => { reportPay(); });
    if (q('other')) q('other').addEventListener('click', () => openOtherPay(selMeeting || nearest));
    form.addEventListener('submit', async (e) => {
      e.preventDefault(); q('fail').textContent = '';
      if (phoneMode) {   // התחברו עם גוגל אבל אין משתתף מקושר: מזינים את הטלפון שבו נרשמו ומחברים אליו את החשבון (החיבור מאושר על ידי מנהל)
        const ph = (root.querySelector('input[type="tel"]') || {}).value || '';
        if (!normPhone(ph)) { q('fail').textContent = 'מספר הטלפון לא תקין'; return; }
        btn.disabled = true; const relB = HRT.busy(btn);
        try {
          const r = await meRpc('harpatka_me_claim', { p_phone: ph });
          if (r === 'invalid_phone') q('fail').textContent = 'מספר הטלפון לא תקין';
          else if (r === 'not_registered') { setPhoneMode(false); q('fail').textContent = 'המספר הזה עוד לא רשום אצלנו. אפשר להשלים כאן הרשמה'; }
          else {   // החיבור מאושר מיד: הפופאפ עובר למצב משתתף מחובר, וההרשמה למפגש שנבחר מתבצעת באותה לחיצה
            setPhoneMode(false); mePending = null;
            for (let i = 0; i < 6 && !meInfo; i++) { await meLoader.now(); if (!meInfo) await new Promise((rs) => setTimeout(rs, 450)); }   // meLoader.now מסתיים מיד כשטעינה אחרת כבר רצה; מנסים עד שהמשתתף נטען
            if (!meInfo) q('fail').textContent = 'משהו השתבש, אפשר לנסות שוב';
            else {
              const mm = selMeeting || nearest, mine = mm && mm.id ? (meInfo.meetings || []).find((y) => y.id === mm.id && y.registered) : null;
              if (mm && mm.id && !mine) { relB(); btn.disabled = false; await memberSubmit(root, btn, q, showDone); return; }
              applyRegState(mm);
            }
          }
        } catch (er) { q('fail').textContent = 'משהו השתבש, אפשר לנסות שוב'; }
        relB(); btn.disabled = false; return;
      }
      if (meInfo) { await memberSubmit(root, btn, q, showDone); return; }   // משתתף מחובר: הפרטים כבר שמורים
      if (GL && !AS && hasSess()) {   // מחובר לגוגל בלי משתתף מקושר: יוצרים משתתף (או מוצאים לפי הטלפון), מחברים את החשבון ונרשמים למפגש באותו צעד
        const ck = PersonForm.validate(root); if (!ck.ok) return;
        const mm = selMeeting || nearest, payOkJ = ageOk(ck.v.age) && !!mm;
        btn.disabled = true; btn.textContent = 'שולחים...'; const relJ = HRT.busy(btn); let doneJ = false;
        try {
          const r = await meRpc('harpatka_me_join', Object.assign({ p_first: ck.v.first, p_last: ck.v.last, p_age: ck.v.age, p_gender: ck.v.gender, p_phone: ck.v.phoneRaw }, mm && mm.id ? { p_meeting: mm.id } : {}, PAID ? { p_src: 'p' } : {}));
          if (r === 'created' || r === 'exists') {
            if (r === 'created') { leadOnce(); try { if (window.fbq) fbq('trackCustom', 'RegistrationValue', { value: ageOk(ck.v.age) ? 3 : 1, currency: 'ILS' }); } catch (e) {} }
            doneJ = true; showDone(payOkJ);
            for (let i = 0; i < 6 && !meInfo; i++) { await meLoader.now(); if (!meInfo) await new Promise((rs) => setTimeout(rs, 450)); }   // המשתתף המקושר נטען: השם בבאנר והמפגשים מתעדכנים
          } else if (PersonForm.serverError(root, r)) { /* ההודעה ליד השדה */ }
          else q('fail').textContent = r === 'phone_taken' ? 'מספר הטלפון הזה כבר נמצא בשימוש' : r === 'blocked' ? 'אי אפשר להירשם מהחשבון הזה' : 'משהו השתבש, אפשר לנסות שוב';   // טלפון של משתתף אחר: ההרשמה לא מתבצעת (והמנהלים מקבלים מייל)
        } catch (er) { q('fail').textContent = 'משהו השתבש, אפשר לנסות שוב'; }
        relJ(); if (!doneJ) { btn.disabled = false; btn.textContent = submitLabel; }
        return;
      }
      const chk = PersonForm.validate(root); if (!chk.ok) return;
      const first = chk.v.first, last = chk.v.last, norm = chk.v.phone, age = chk.v.age, gender = chk.v.gender;
      /* אפשרות תשלום רק בטווח הגילאים של קהל היעד (AGE_MIN עד AGE_MAX ב-shared/age.js; ההרשמה עצמה נשמרת תמיד) */
      /* תשלום רק אחרי הרשמה למפגש: בלי מפגש (השארת פרטים בלבד) אין כפתור תשלום */
      const payOk = ageOk(age) && !!(selMeeting || nearest);
      const allDone = () => { suRoots.forEach(f => f(payOk)); };   // בלי שמירה בדפדפן: בכל טעינה של הדף הטופס מוצג מחדש
      if (q('hp').value || Date.now() - t0 < 1500) { allDone(); return; }   // בוט: מציגים הצלחה בלי לשמור
      btn.disabled = true; btn.textContent = 'שולחים...';
      const relBtn = HRT.busy(btn);   // אפקט המתנה על הכפתור עד שהתשובה מגיעה
      let finished = false;
      const claimToken = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : null;   // אסימון חיבור לאזור האישי (נשמר על המשתתף החדש בלבד)
      try {
        const send = (extra) => fetch(CONFIG.supabaseUrl + '/rest/v1/rpc/harpatka_signup', {
          method: 'POST',
          headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey, 'Content-Type': 'application/json' },
          body: JSON.stringify(Object.assign({ p_first: first, p_last: last, p_phone: norm, p_age: age, p_gender: gender }, claimToken ? { p_token: claimToken } : {}, selMeeting && selMeeting.id ? { p_meeting: selMeeting.id } : {}, extra))
        });
        let res = await send(PAID ? { p_src: 'p' } : {});
        if (!res.ok && PAID) res = await send({});   // אם הפונקציה בבסיס הנתונים עוד לא עודכנה (admin/source.sql): ההרשמה נשמרת בלי הסימון
        const out = res.ok ? await res.json() : null;
        if (out === 'created' || out === 'exists') {   // כפילות: אותה הודעה, בלי לחשוף שהמספר כבר רשום
          if (out === 'created') {   // Lead רק על מספר חדש (חד ערכי), לא על כפילות
            try { if (claimToken) localStorage.setItem('harpatka_claim_token', claimToken); } catch (e) {}   // האזור האישי יחבר את המשתתף לחשבון גוגל בלי טלפון
            leadOnce();
            /* RegistrationValue: ערך 3 למי שבטווח הגילאים (זהה ל-payOk), 1 למי שמחוץ לטווח */
            const inRange = ageOk(age);
            try { if (window.fbq) fbq('trackCustom', 'RegistrationValue', { value: inRange ? 3 : 1, currency: 'ILS' }); } catch (e) {}
          }
          finished = true; allDone();
        } else if (PersonForm.serverError(root, out)) { /* ההודעה הוצגה ליד השדה */ }
        else throw new Error('signup failed');
      } catch (err) {
        q('fail').innerHTML = 'משהו השתבש, אפשר ליצור קשר ישירות: <a href="#" class="underline font-bold">שיחה בוואטסאפ</a>';
        q('fail').querySelector('a').addEventListener('click', ev => { ev.preventDefault(); const m = document.getElementById('contactModal'); if (m) { if (m.hidden) openModal(m); showChoose(); } });
      }
      relBtn();
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
  /* ===== משתתף מחובר (חשבון גוגל מהאזור האישי, אותו מפתח session של me/): הרשמה למפגש בלחיצה אחת, בלי הזנת פרטים ===== */
  const ME_KEY = 'harpatka_me_session';
  /* צפייה כמשתתף (מנהל, מהעין בפרטי המשתתף בדף הניהול): /?as=<מזהה המשתתף>. הדף מתנהג כאילו המשתתף מחובר עם גוגל (השם בבאנר, המפגשים, הרשמה ותשלום, האזור האישי),
     בלי חיבור אמיתי: הבקשות יוצאות עם החיבור של דף הניהול ועם p_as (השרת בודק שהמבקש מנהל). החיבור והשם השמורים של הדפדפן לא משתנים */
  const AS = (() => { try { const v = new URLSearchParams(location.search).get('as'); return v && /^[0-9a-f-]{36}$/i.test(v) ? v : null; } catch (e) { return null; } })();
  const TOK_KEY = AS ? 'harpatka_admin_session_v2' : ME_KEY;
  window.__meAs = AS;
  let meInfo = null;   // { first, last, age, gender, meetings }
  const hasSess = () => { try { return !!localStorage.getItem(TOK_KEY); } catch (e) { return false; } };   // יש חיבור גוגל שמור בדפדפן (גם אם עוד לא נטען המשתתף)
  /* מחובר באמת: המשתתף נטען מהשרת, או שיש חיבור שמור שעוד לא פג. חיבור שמור שפג (ואולי הרענון שלו נכשל) לא נחשב: הכפתורים פותחים כניסה עם גוגל */
  const loggedIn = () => { if (meInfo) return true; try { const s = JSON.parse(localStorage.getItem(TOK_KEY) || 'null'); return !!(s && s.access_token && jwtExp(s.access_token) * 1000 > Date.now() + 30000); } catch (e) { return false; } };
  const REG_MEET_KEY = 'harpatka_reg_meeting';   // המפגש שנבחר להרשמה לפני הכניסה עם גוגל (גם אם הכניסה עברה בניווט רגיל)
  const takeRegMeeting = () => { let m = null; try { m = JSON.parse(sessionStorage.getItem(REG_MEET_KEY) || 'null'); sessionStorage.removeItem(REG_MEET_KEY); } catch (e) {} return m && m.id ? m : null; };
  const jwtExp = (tok) => { try { return JSON.parse(atob(tok.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).exp || 0; } catch (e) { return 0; } };
  async function meToken() {
    let s = null; try { s = JSON.parse(localStorage.getItem(TOK_KEY) || 'null'); } catch (e) {}
    if (!s || !s.access_token) return null;
    if (jwtExp(s.access_token) * 1000 > Date.now() + 30000) return s.access_token;
    if (!s.refresh_token) return null;
    try {
      const r = await fetch(CONFIG.supabaseUrl + '/auth/v1/token?grant_type=refresh_token', { method: 'POST', headers: { apikey: CONFIG.supabaseKey, 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: s.refresh_token }) });
      if (!r.ok) return null;
      const d = await r.json(); try { localStorage.setItem(TOK_KEY, JSON.stringify({ access_token: d.access_token, refresh_token: d.refresh_token })); } catch (e) {}
      return d.access_token;
    } catch (e) { return null; }
  }
  async function meRpc(name, body) {
    const tok = await meToken(); if (!tok) throw new Error('auth');
    const r = await fetch(CONFIG.supabaseUrl + '/rest/v1/rpc/' + name, { method: 'POST', headers: { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + tok, 'Content-Type': 'application/json' }, body: JSON.stringify(Object.assign({}, body || {}, AS ? { p_as: AS } : {})) });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  }
  /* משתתף מחובר שכבר רשום למפגש שנבחר: הפופאפ במצב תשלום ולא במצב הרשמה: בלי כפתור "הרשמה"; מוצגים מצב המפגש (נרשמתם), כפתור התשלום בפייבוקס והקישורים (דיווח, תשלום בדרך אחרת),
     או הודעה אם כבר שולם, חינם או דווח. מפגש שלא נרשם אליו: הפופאפ כרגיל */
  let NOTE0 = null;
  function applyRegState(m) {
    const root = contactModal; if (!root) return;
    const q = (k) => root.querySelector('[data-su="' + k + '"]'), btn = q('btn'), after = q('after'), note = root.querySelector('.su-paynote'), fold = q('payfold'), rep = q('reported');
    if (!btn || !after || !note) return;
    if (NOTE0 == null) NOTE0 = note.innerHTML;
    const x = meInfo && m && m.id ? (meInfo.meetings || []).find((y) => y.id === m.id && y.registered) : null;
    if (!x) {
      if (root.dataset.regState) {   // חזרה למצב הרשמה רגיל
        delete root.dataset.regState; btn.hidden = false; note.innerHTML = NOTE0; if (fold) fold.hidden = false; if (rep) rep.hidden = true;
        if (!btn.classList.contains('saved')) { after.classList.add('shut'); root.querySelectorAll('.su-fold:not(.su-after)').forEach((f) => f.classList.remove('shut')); }
      }
      return;
    }
    const paid = Number(x.paid) > 0, free = !!x.free, reported = !!x.reported, rejected = !!x.rejected && !reported;
    root.dataset.regState = '1';
    btn.hidden = true;
    root.querySelectorAll('.su-fold:not(.su-after)').forEach((f) => f.classList.add('shut'));
    after.classList.remove('shut');
    note.innerHTML = '<span class="su-regd">נרשמתם למפגש</span>' + (free ? 'המפגש בשבילכם ללא תשלום' : paid ? 'התשלום התקבל. נתראה!' : reported ? 'התשלום ממתין לאישור שלנו' : rejected ? 'לא מצאנו את התשלום. אפשר להשלים אותו כאן' : 'המקום יישמר קבוע רק לאחר תשלום');   // "נרשמתם למפגש" בשורה משלו בכתום, והמצב מתחתיו
    if (fold) fold.hidden = paid || free || reported;
    if (rep) rep.hidden = !reported;
  }
  let phoneMode = false;   // מחוברים עם גוגל, אין משתתף מקושר: פופאפ ההרשמה במצב הזנת טלפון בלבד
  function setPhoneMode(on) {
    phoneMode = !!on; document.documentElement.classList.toggle('reg-phone', phoneMode);
  }
  const applyMemberMode = () => {
    const on = !!meInfo;
    document.documentElement.classList.toggle('reg-member', on);
    document.documentElement.classList.toggle('reg-join', !on && GL && !AS && loggedIn());   // מחובר לגוגל בלי משתתף מקושר: הטופס המלא (השלמת פרטים)
    document.querySelectorAll('[data-su="who"]').forEach((e) => { e.textContent = on ? meInfo.first + ' ' + meInfo.last : ''; });
    if (on) { window.__meName = meInfo.first + ' ' + meInfo.last; try { window.dispatchEvent(new Event('harpatka:me')); } catch (e) {} }
  };
  /* התחברות עם גוגל ישר מדף הבית (בלי לעבור באזור האישי): חוזרים לאותו עמוד עם הטוקן ב-hash, שומרים אותו, ואם אין משתתף מקושר פותחים את פופאפ ההרשמה */
  const LOGIN_KEY = 'harpatka_login_pending';   // '1': פתיחת הרשמה רק אם אין משתתף; 'reg': תמיד לפתוח את פופאפ ההרשמה אחרי ההתחברות
  function loginGoogle(after) {
    try { sessionStorage.setItem(LOGIN_KEY, after || '1'); } catch (e) {}
    location.href = CONFIG.supabaseUrl + '/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=' + encodeURIComponent(location.origin + location.pathname);
  }
  /* כניסה עם גוגל בחלון קופץ: הדף לא מתרענן ולא עובר לשום מקום. החלון הקופץ חוזר ל-me/, שומר את החיבור ב-localStorage, מסמן harpatka_login_done וסוגר את עצמו;
     כאן מאזינים לסימון (אירוע storage), טוענים את המשתתף ומרעננים את הפופאפ הפתוח. אם החלון נחסם: ניווט רגיל כמו קודם */
  function loginPopup(after, thenOpen) {
    if (!GL) return;
    try { localStorage.setItem('harpatka_login_popup', '1'); } catch (e) {}
    const url = CONFIG.supabaseUrl + '/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=' + encodeURIComponent(BASE + 'me/');
    const w = window.open(url, 'harpatka_login', 'width=480,height=680');
    if (!w) { try { localStorage.removeItem('harpatka_login_popup'); if (thenOpen) sessionStorage.setItem('harpatka_open_me', '1'); } catch (e) {} return loginGoogle(after); }
    const onDone = (ev) => {
      if (ev.key !== 'harpatka_login_done') return;
      window.removeEventListener('storage', onDone); clearInterval(iv);
      mePending = after || null; const ld = meLoader.now();
      if (meSheet) { meSheet.dataset.k = ''; if (!meSheet.hidden) { const f = meSheet.querySelector('iframe'), s = f.src; f.src = s; } }
      if (thenOpen) Promise.resolve(ld).then(() => openMeArea(''));   // נכנסו מ"כניסה לאזור האישי": אחרי ההתחברות נפתח האזור האישי
    };
    window.addEventListener('storage', onDone);
    const iv = setInterval(() => { if (w.closed) { clearInterval(iv); setTimeout(() => window.removeEventListener('storage', onDone), 1500); try { localStorage.removeItem('harpatka_login_popup'); } catch (e) {} } }, 800);
  }
  function takeLoginHash() {
    const h = new URLSearchParams(location.hash.replace(/^#/, ''));
    if (h.get('access_token')) {
      try { localStorage.setItem(ME_KEY, JSON.stringify({ access_token: h.get('access_token'), refresh_token: h.get('refresh_token') })); } catch (e) {}
      try { history.replaceState(null, '', location.pathname + location.search); } catch (e) {}
      return true;
    }
    if (h.get('error_description')) { try { history.replaceState(null, '', location.pathname + location.search); sessionStorage.removeItem(LOGIN_KEY); } catch (e) {} }
    return false;
  }
  const clearMeName = () => { if (!AS) try { localStorage.removeItem('harpatka_me_name'); } catch (e) {} if (window.__meName) { window.__meName = null; } try { window.dispatchEvent(new Event('harpatka:me')); } catch (e) {} };
  /* מצב המשתתף המחובר נטען דרך HRT.loader: טעינה אחת בכל פעם, תוצאה ישנה לא דורסת חדשה, ושינויים שלי (הרשמה, דיווח) שעוד לא נקלטו מוחלים על כל טעינה שהתחילה לפניהם */
  let mePending = null;
  const meLoader = HRT.loader(async () => {
    if (!(await meToken())) return { status: 'noauth' };
    return meRpc('harpatka_me', {});
  }, (d) => {
    const pending = mePending; mePending = null;
    window.__meAdmin = false;   // מנהל הוא גם משתתף: בדף הבית מתנהג בדיוק כמו כל משתתף (אזור אישי והרשמה), בלי מעבר לדף הניהול
    if (d && d.status === 'ok' && d.participant && d.participant.first_name) {
      meInfo = { first: d.participant.first_name, last: d.participant.last_name || '', age: d.participant.age, gender: d.participant.gender, meetings: d.meetings || [] };
      applyMemberMode(); applyRegState(selMeeting || nearest);
      if (!AS) try { localStorage.setItem('harpatka_me_name', meInfo.first + ' ' + meInfo.last); } catch (e) {}
      ensureMeChannel();
      if (!meSheet && !window.__meAdmin) setTimeout(() => { try { openMeArea('', true); } catch (e) {} }, 1500);   // טעינה מוקדמת של האזור האישי (מוסתר), כדי שהפתיחה הראשונה תהיה מיידית
      if (pending === 'reg') setTimeout(() => openReg(true, takeRegMeeting()), 300);   // נכנסו עם גוגל מתוך הרשמה: פופאפ ההרשמה של המפגש שנבחר, במצב מחובר
    } else if (d && d.status === 'noauth') { window.__meAdmin = false; clearMeName(); }
    else { clearMeName(); if (pending === 'reg' && !AS) setTimeout(() => openReg(true, takeRegMeeting()), 300); }   // מחובר לגוגל אבל אין משתתף מקושר: פופאפ ההרשמה עם הזנת הפרטים (יוצר משתתף, מחבר את החשבון ונרשם באותו צעד)
  });
  const GL = CONFIG.googleLogin !== false || !!AS;   // מתג כניסה עם גוגל (shared/config.js); בצפייה כמשתתף הדף מתנהג כמחובר גם כשהכניסה לציבור כבויה
  if (CONFIG.googleLogin === false && !AS) document.documentElement.classList.add('no-gl');   // כניסה עם גוגל כבויה: בלי כרטיס האזור האישי ובלי קישורי הכניסה. בצפייה כמשתתף הכרטיס מוצג ופותח את האזור האישי שלו
  function loadMe() {
    if (!GL) return Promise.resolve();
    takeLoginHash();
    try { const pd = sessionStorage.getItem(LOGIN_KEY); if (pd) { mePending = pd; sessionStorage.removeItem(LOGIN_KEY); } } catch (e) {}
    return meLoader.now();   // תקלה זמנית: ממשיכים כאורח, עם הטופס הרגיל
  }
  /* שינוי של המשתתף על מפגש (הרשמה, דיווח תשלום): מוצג מיד, נשמר גם מול טעינות שהתחילו לפני שהשרת קלט אותו, ומתבטל אם השליחה נכשלת */
  function meOptimistic(mid, patch) {
    const apply = (d) => { const mm = ((d && d.meetings) || []).find((x) => x.id === mid); if (mm) Object.assign(mm, patch); };
    const h = HRT.optimistic(apply);
    if (meInfo) { apply(meInfo); try { window.dispatchEvent(new Event('harpatka:me')); } catch (e) {} }
    return { done: h.done, fail: () => { h.fail(); meLoader.reload(0); } };
  }
  async function memberSubmit(root, btn, q, showDone) {
    const m = selMeeting || nearest, fail = q('fail'); fail.textContent = '';
    if (!m || !m.id) { fail.textContent = 'עוד אין מפגש להירשם אליו. נעדכן ברגע שייקבע'; return; }
    btn.disabled = true; btn.textContent = 'שולחים...';
    const ob = meOptimistic(m.id, { registered: true }), rel = HRT.busy(btn);
    try {
      const r = await meRpc('harpatka_me_register', { p_meeting: m.id });
      if (r !== 'registered' && r !== 'exists') throw new Error('register failed');
      ob.done(); rel();
      const mine = meInfo.meetings.find((x) => x.id === m.id);
      const payOk = ageOk(meInfo.age) && !(mine && (Number(mine.paid) > 0 || mine.free));
      showDone(payOk); meLoader.reload(0); return;   // טעינה מחדש של המצב (השינוי שלי כבר מוצג ונשמר מול טעינות ישנות)
    } catch (e) { ob.fail(); rel(); fail.textContent = 'משהו השתבש, אפשר לנסות שוב'; }
    btn.disabled = false; btn.textContent = submitLabel;
  }
  /* יציאה מהחשבון (לחיצה על השם בבאנר): שואלים לפני שמנתקים */
  function confirmLogout() {
    if (!meInfo) return;
    const m = document.getElementById('logoutModal');
    m.querySelector('#logoutTtl').textContent = 'מחוברים כ' + meInfo.first + ' ' + meInfo.last;
    if (!m.dataset.bound) {
      m.dataset.bound = '1';
      m.querySelector('[data-lg="yes"]').addEventListener('click', () => {
        if (AS) { if (window.top !== window) { try { parent.postMessage({ harpatka: 'me-logout' }, location.origin); } catch (er) {} } else location.href = location.pathname; return; }   // צפייה כמשתתף: "יציאה" = סיום הצפייה (בפופאפ של דף הניהול: סגירתו), בלי לנתק את החיבור של הדפדפן
        try { localStorage.removeItem(ME_KEY); localStorage.removeItem('harpatka_me_name'); } catch (er) {}
        meInfo = null; window.__meName = null; window.__meAdmin = false; applyMemberMode(); try { window.dispatchEvent(new Event('harpatka:me')); } catch (er) {}
        closeModal(m);
      });
    }
    openModal(m, true);
  }
  /* מצב מפגש של המשתתף המחובר (להצגה בכפתור של כרטיסי המפגשים בדף הבית) */
  const meGet = (mid) => (meInfo && (meInfo.meetings || []).find((x) => x.id === mid)) || null;
  /* תשלום בדרך אחרת: פופאפ (אותה מעטפת) עם שיחת וואטסאפ מוכנה להדר או לאופיר, עם פרטי המפגש */
  function openOtherPay(m) {
    const dlg = document.getElementById('otherModal'); if (!dlg) return;
    let info = 'המפגש הקרוב';
    if (m && m.date) { const [, mo, d] = String(m.date).split('-').map(Number), wd = HE_DAYS[new Date(m.date + 'T12:00:00Z').getUTCDay()]; info = 'יום ' + wd + ' ' + d + '.' + mo + (m.time ? ' בשעה ' + m.time : ''); }
    const text = 'היי, אני רוצה להעביר את התשלום בדרך אחרת למפגש ביום ' + info.replace(/^יום /, '');
    const wa = (num) => 'https://wa.me/' + num + '?text=' + encodeURIComponent(text);
    dlg.querySelector('#otherInfo').textContent = info;
    dlg.querySelector('#otherHadar').href = wa(CONFIG.whatsappHadar); dlg.querySelector('#otherOfir').href = wa(CONFIG.whatsappOfir);
    openModal(dlg, true);
  }
  /* פופאפ האזור האישי: עולה מלמטה ומציג את דף האזור האישי (me/?embed=1) בתוך iframe, בלי לעבור לדף אחר. סגירה: גרירה למטה או לחיצה על הפס, לחיצה בחוץ, Esc וכפתור "חזרה" */
  /* מנהל: דף הניהול שומר את החיבור במפתח משלו, ולכן מעתיקים אליו את החיבור של דף הבית ועוברים אליו (בלי להתחבר שוב) */
  function goAdmin() { try { const s = localStorage.getItem(ME_KEY); if (s) localStorage.setItem('harpatka_admin_session_v2', s); } catch (e) {} location.href = BASE + 'admin/'; }
  let meSheet = null, meSheetPush = false;
  function closeMeSheet(fromPop) {
    if (!meSheet || meSheet.hidden) return;
    meSheet.classList.remove('open'); unlockPage();
    if (meSheetPush && !fromPop) { meSheetPush = false; try { history.back(); } catch (e) {} } else meSheetPush = false;
    const sh = meSheet; setTimeout(() => { sh.hidden = true; }, 340);
    try { meLoader.reload(250); } catch (e) {}   // מה ששונה באזור האישי מתעדכן בדף
  }
  function openMeArea(search, preload) {
    if (!GL) return;
    if (!AS && !preload && !loggedIn()) { loginPopup('', true); return; }   // לא מחובר: ישר כניסה עם גוגל (בחלון קופץ), בלי מסך כניסה; אחרי ההתחברות האזור האישי נפתח
    const lm = document.getElementById('logoutModal'); if (!preload && lm && !lm.hidden) { try { closeModal(lm); } catch (e) {} }
    if (!meSheet) {
      meSheet = document.createElement('div'); meSheet.className = 'mesheet'; meSheet.hidden = true; meSheet.setAttribute('role', 'dialog'); meSheet.setAttribute('aria-modal', 'true'); meSheet.setAttribute('aria-label', 'האזור האישי');
      meSheet.innerHTML = '<div class="mesb"></div><div class="mesp"><button type="button" class="mesgrab" aria-label="סגירה"><i></i></button><iframe class="mesf" title="האזור האישי"></iframe></div>';
      document.body.appendChild(meSheet);
      meSheet.querySelector('.mesb').addEventListener('click', () => closeMeSheet());
      const g = meSheet.querySelector('.mesgrab'), p = meSheet.querySelector('.mesp'); let sy = 0, dy = 0, dr = false;
      g.addEventListener('pointerdown', (e) => { dr = true; sy = e.clientY; dy = 0; p.style.transition = 'none'; try { g.setPointerCapture(e.pointerId); } catch (x) {} });
      g.addEventListener('pointermove', (e) => { if (!dr) return; dy = Math.max(0, e.clientY - sy); p.style.transform = 'translateY(' + dy + 'px)'; });
      const end = () => { if (!dr) return; dr = false; p.style.transition = ''; p.style.transform = ''; if (dy > 70 || dy < 4) closeMeSheet(); };
      g.addEventListener('pointerup', end); g.addEventListener('pointercancel', end);
      document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMeSheet(); });
      window.addEventListener('popstate', () => { if (meSheetPush) { meSheetPush = false; closeMeSheet(true); } });
      window.addEventListener('message', (e) => {
        if (e.origin === location.origin && e.data && e.data.harpatka === 'me-login') {   // בתוך הפופאפ התברר שהחיבור לא תקף: סוגרים אותו ופותחים כניסה עם גוגל, ואחריה הפופאפ נפתח שוב
          if (!meSheet || meSheet.hidden) { if (meSheet) meSheet.dataset.k = ''; return; }   // פופאפ מוסתר (טעינה מוקדמת ברקע): לא פותחים כניסה מעצמה, רק טוענים מחדש בפתיחה הבאה
          closeMeSheet();
          if (!AS) { try { localStorage.removeItem(ME_KEY); } catch (er) {} meInfo = null; applyMemberMode(); setTimeout(() => loginPopup('', true), 380); }
          return;
        }
      });
      window.addEventListener('message', (e) => {   // החלקה למטה בתוך הדף (כשהוא בראשו) מזיזה את כל הפופאפ וסוגרת אותו
        if (e.origin !== location.origin || !e.data || !meSheet || meSheet.hidden) return;
        const t = e.data.harpatka, d = Math.max(0, Number(e.data.dy) || 0);
        if (t === 'me-drag') { p.style.transition = 'none'; p.style.transform = 'translateY(' + d + 'px)'; }
        else if (t === 'me-drag-end') { p.style.transition = ''; p.style.transform = ''; if (d > 110) closeMeSheet(); }
      });
      window.addEventListener('message', (e) => { if (e.origin === location.origin && e.data && e.data.harpatka === 'me-logout' && AS) { closeMeSheet(); if (window.top !== window) { try { parent.postMessage({ harpatka: 'me-logout' }, location.origin); } catch (er) {} } else location.href = location.pathname; return; } if (e.origin === location.origin && e.data && e.data.harpatka === 'me-logout') { try { localStorage.removeItem(ME_KEY); localStorage.removeItem('harpatka_me_name'); } catch (er) {} meInfo = null; window.__meName = null; window.__meAdmin = false; applyMemberMode(); try { window.dispatchEvent(new Event('harpatka:me')); } catch (er) {} meSheet.dataset.k = ''; closeMeSheet(); } });   // יציאה: מנתקים וסוגרים את הפופאפ, בלי לרענן את הדף
    }
    const qs = new URLSearchParams(search || ''); qs.set('embed', '1'); if (AS) qs.set('as', AS);   // צפייה כמשתתף: האזור האישי של אותו משתתף, עם החיבור של דף הניהול
    { const fr = meSheet.querySelector('iframe'); let tk = ''; try { tk = String(localStorage.getItem(TOK_KEY) || '').slice(-24); } catch (e) {}
      const key = tk + '|' + qs.toString();
      if (meSheet.dataset.k !== key) { fr.src = BASE + 'me/?' + qs.toString(); meSheet.dataset.k = key; } }   // הדף נטען מראש ונשאר חם: פתיחה ראשונה ופתיחות הבאות מיידיות; נטען מחדש רק כשהחיבור או הפרמטרים השתנו
    if (preload) return;
    meSheet.hidden = false; lockPage();
    requestAnimationFrame(() => requestAnimationFrame(() => meSheet.classList.add('open')));
    if (!meSheetPush) { try { history.pushState({ meSheet: 1 }, ''); meSheetPush = true; } catch (e) {} }
  }
  document.addEventListener('click', (e) => {   // קישור לאזור האישי (כרטיס האזור האישי, כפתור המפגש, קישורי ההרשמה): פותחים את הפופאפ במקום לעבור לדף
    const a = e.target.closest && e.target.closest('a[href]'); if (!a || e.defaultPrevented || e.button || e.ctrlKey || e.metaKey || e.shiftKey || a.target === '_blank') return;
    let u; try { u = new URL(a.getAttribute('href'), location.href); } catch (x) { return; }
    if (!a.closest('#meAreaCard') || u.origin !== location.origin || !/\/me\/?$/.test(u.pathname) || u.searchParams.has('as') || u.searchParams.has('back')) return;   // פופאפ האזור האישי נפתח רק מהכרטיס "האזור האישי שלכם"
    e.preventDefault(); e.stopPropagation();
    if (!GL) return;   // כניסה עם גוגל כבויה: הכרטיס מוצג, והלחיצה לא עושה כלום (בינתיים)
    openMeArea(u.search);   // מחובר: הפופאפ נפתח מיד; לא מחובר: קודם כניסה עם גוגל, ואחריה הפופאפ נפתח (openMeArea → loginPopup)
  }, true);
  window.HarpatkaMe = { enabled: GL, confirmLogout, get: meGet, login: loginGoogle, loginPopup, openArea: (search) => openMeArea(search || '') };
  try { if (sessionStorage.getItem('harpatka_open_me')) { sessionStorage.removeItem('harpatka_open_me'); setTimeout(() => { try { if (localStorage.getItem(ME_KEY)) openMeArea(''); } catch (e) {} }, 700); } } catch (e) {}   // חזרה מהתחברות עם גוגל שהתחילה מתוך הפופאפ: נפתח מחדש
  document.querySelectorAll('[data-su="ame"]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); try { closeModal(contactModal); } catch (x) {} setTimeout(() => openMeArea(''), 450); }));   // כניסה לאזור האישי (בתחתית אחרי ההרשמה): סוגרים את פופאפ ההרשמה ופותחים את האזור האישי
  document.querySelectorAll('[data-su="glink"]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); loginPopup('reg'); }));   // נרשמתם בעבר: כניסה עם גוגל בחלון קופץ; אחרי החיבור פופאפ ההרשמה עובר למצב משתתף מחובר (בלי לפתוח את האזור האישי)
  loadMe();
  /* זמן אמת: מצב המשתתף המחובר דרך הערוץ "me" (בבדיקות "me-test"), ומפגשים והגדרות ציבוריות דרך הערוץ "meetings" (גם למבקרים לא מחוברים).
     הערוצים, חיבור מחדש, חזרה ללשונית וגיבוי כל 45 שניות מגיעים מ-HRT.channel */
  const IS_TEST = !!(window.HARPATKA_ENV && window.HARPATKA_ENV.name === 'test');
  let meChan = null;
  function ensureMeChannel() {
    if (meChan || !GL) return;
    meChan = HRT.channel({ url: CONFIG.supabaseUrl, key: CONFIG.supabaseKey }, IS_TEST ? 'me-test' : 'me', () => { try { if (!meInfo && !localStorage.getItem(TOK_KEY)) return; } catch (e) { return; } meLoader.reload(250); }, { poll: 45000 });
  }
  try { if (localStorage.getItem(TOK_KEY)) ensureMeChannel(); } catch (e) {}
  HRT.channel({ url: CONFIG.supabaseUrl, key: CONFIG.supabaseKey }, IS_TEST ? 'meetings-test' : 'meetings', () => { setTimeout(() => { loadNearest(); try { window.dispatchEvent(new Event('harpatka:meetings')); } catch (e) {} }, 200 + Math.random() * 800); }, { poll: 90000 });   // פיזור קטן כדי שכל המבקרים לא יטענו באותו רגע
  const contactModal = document.getElementById('contactModal');
  /* השלמת פרטים אחרי כניסה עם גוגל: שם פרטי ושם משפחה מהחשבון (רק בשדות ריקים) */
  function prefillGoogleName() {
    if (!document.documentElement.classList.contains('reg-join')) return;
    let md = {}; try { const s = JSON.parse(localStorage.getItem(TOK_KEY) || 'null'); md = JSON.parse(decodeURIComponent(escape(atob(s.access_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))))).user_metadata || {}; } catch (e) {}
    const full = String(md.full_name || md.name || '').trim(), first = md.given_name || full.split(' ')[0] || '', last = md.family_name || full.split(' ').slice(1).join(' ');
    const f = document.getElementById('cmFirst'), l = document.getElementById('cmLast');
    if (f && !f.value && first) f.value = first; if (l && !l.value && last) l.value = last;
  }
  function openReg(auto, meeting) { selMeeting = meeting && meeting.id ? meeting : null; showMeeting(selMeeting || nearest); applyMemberMode(); prefillGoogleName(); applyRegState(selMeeting || nearest); if (contactModal) openModal(contactModal, auto === true); }
  /* הרשמה כשהכניסה עם גוגל פעילה: מי שלא מחובר עובר קודם לכניסה עם גוגל (בלי פופאפ); אחרי הכניסה נפתח פופאפ ההרשמה של המפגש שנבחר:
     משתתף מקושר: הרשמה בלחיצה; בלי משתתף מקושר: הזנת פרטים, והכפתור יוצר משתתף, מחבר את החשבון ונרשם באותו צעד (harpatka_me_join) */
  window.HarpatkaRegister = { open: (auto, meeting) => {
    if (GL && !AS && !loggedIn()) { try { sessionStorage.setItem(REG_MEET_KEY, JSON.stringify(meeting && meeting.id ? meeting : null)); } catch (e) {} loginPopup('reg'); return; }
    openReg(auto, meeting);
  } };   // לשימוש עמודים אחרים
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
  let defMeetingName = '';   // שם ברירת המחדל למפגש (harpatka_public_settings)
  const showMeeting = (m) => {
    setSubmitLabel(m);
    document.querySelectorAll('.mt-badge').forEach((e) => { e.hidden = !m; });   // אין מפגש: אין שורת תאריך בכותרת
    { const nm = (m && m.name) || defMeetingName || ''; document.querySelectorAll('[data-meeting-name]').forEach((e) => { e.textContent = nm; e.hidden = !nm; }); }   // כותרת: שם המפגש, ואם אין לו שם: שם ברירת המחדל
    if (!m) { document.querySelectorAll('[data-price]').forEach((e) => { e.textContent = priceFor(999, null) + ' ₪'; }); return; }
    const [, mo, d] = m.date.split('-').map(Number), wd = HE_DAYS[new Date(m.date + 'T12:00:00Z').getUTCDay()];
    const when = 'יום ' + wd + ' ' + Number(d) + '.' + Number(mo) + (m.time ? ' · ' + m.time : '') + (m.city ? ' · ' + m.city : '');
    document.querySelectorAll('[data-meeting-when]').forEach((e) => { e.textContent = when; });
    document.querySelectorAll('[data-meeting-place]').forEach((e) => { e.textContent = CONFIG.meetingPlace || ''; });
    const left = dayN(m.date) - dayN(new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date()));
    const price = priceFor(left, m.tiers);
    document.querySelectorAll('[data-price]').forEach((e) => { e.textContent = price + ' ₪'; });
  };
  showMeeting(nearest);   // מיד, בלי להמתין לרשת
  const loadNearest = async () => {
    const H = { apikey: CONFIG.supabaseKey, Authorization: 'Bearer ' + CONFIG.supabaseKey };
    try {
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jerusalem' }).format(new Date());
      const r = await fetch(CONFIG.supabaseUrl + '/rest/v1/harpatka_meetings?select=id,meeting_date,meeting_time,price_tiers,name,city&meeting_date=gte.' + today + '&order=meeting_date.asc,meeting_time.asc&limit=1', { headers: H });
      const rows = r.ok ? await r.json() : [];
      if (r.ok && !(rows && rows[0])) nearest = null;   // אין מפגש עתידי
      try { const sr = await fetch(CONFIG.supabaseUrl + '/rest/v1/harpatka_public_settings?select=key,value&key=eq.default_meeting_name', { headers: H }); const sv = sr.ok ? await sr.json() : []; defMeetingName = String(((sv[0] || {}).value) || '').trim(); } catch (e) {}
      if (rows && rows[0]) nearest = { id: rows[0].id, date: rows[0].meeting_date, time: String(rows[0].meeting_time).slice(0, 5), tiers: normT(rows[0].price_tiers), name: String(rows[0].name || '').trim(), city: String(rows[0].city || '').trim() };
      showMeeting(selMeeting || nearest);
    } catch (e) {}
  };
  loadNearest();
})();
