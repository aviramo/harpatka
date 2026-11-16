/* מתאם בין האתר ל-API של רוסטר (העסק harpatka). פעיל רק כש-CONFIG.rosterApi.authUrl מוגדר (כרגע רק בסביבת הבדיקות, מוזרק ב-tools/deploy-test.py); בלי זה הקובץ לא עושה כלום.
   האתר ממשיך לדבר בשפה של הרפתקה (harpatka_me, harpatka_signup_phone, harpatka_meetings...), והמתאם מתרגם כל בקשה ל-Supabase של הרפתקה לרוסטר:
     התחברות (/auth/v1/*)                            -> האימות של floa (אותו אישור גוגל של האפליקציה של הרפתקה, מוחלף שם בחיבור)
     harpatka_me*                                     -> me* של רוסטר (סכמת roster-test), עם החיבור של המשתתף
     harpatka_signup_phone / _complete / report_token -> POST /signup/phone, /signup/complete, /payments/click ב-API הציבורי
     harpatka_meetings, _meeting_types, _public_settings (קריאה) -> GET /meetings?past=3 ב-API הציבורי
   אחרי המעבר הסופי מחליפים את הקריאות באתר לקריאות ישירות ומוחקים את הקובץ. */
(function () {
  'use strict';
  var C = (typeof CONFIG !== 'undefined') ? CONFIG : null, R = C && C.rosterApi;   // CONFIG הוא const גלובלי (לא מאפיין של window)
  if (!R || !R.authUrl || !R.authKey || !window.fetch || window.__rosterBridge) return;
  window.__rosterBridge = true;
  var SB = C.supabaseUrl, real = window.fetch.bind(window), TOK = 'harpatka_roster_token';

  var ME = {
    harpatka_me: 'me', harpatka_me_phone: 'me_phone', harpatka_me_complete: 'me_complete', harpatka_me_register: 'me_register', harpatka_me_register_src: 'me_register',
    harpatka_me_unregister: 'me_unregister', harpatka_me_pay_credit: 'me_pay_credit', harpatka_me_report_payment: 'me_report_payment', harpatka_me_update: 'me_update', harpatka_me_buy_pass: 'me_buy_pass'
  };
  var FIELD_CODE = { first_name: 'invalid_name', last_name: 'invalid_name', phone: 'invalid_phone', age: 'invalid_age', gender: 'invalid_gender', email: 'invalid_email' };

  var reply = function (body, status) { return new Response(JSON.stringify(body), { status: status || 200, headers: { 'Content-Type': 'application/json' } }); };
  function headersOf(init) {
    var h = {}, s = init && init.headers;
    if (!s) return h;
    if (typeof s.forEach === 'function' && !Array.isArray(s)) s.forEach(function (v, k) { h[k.toLowerCase()] = v; });
    else if (Array.isArray(s)) s.forEach(function (p) { h[String(p[0]).toLowerCase()] = p[1]; });
    else Object.keys(s).forEach(function (k) { h[k.toLowerCase()] = s[k]; });
    return h;
  }
  function bodyOf(init) { try { return init && init.body ? JSON.parse(init.body) : {}; } catch (e) { return {}; } }
  var getTok = function () { try { return localStorage.getItem(TOK) || ''; } catch (e) { return ''; } };
  var setTok = function (t) { try { localStorage.setItem(TOK, t); } catch (e) {} };
  var roster = function (path, opt) {
    return real(R.url + path, Object.assign({ headers: { Authorization: 'Bearer ' + R.key, 'Content-Type': 'application/json' } }, opt || {}));
  };
  var errField = async function (r) { try { var j = await r.json(); return (j && j.error && j.error.field) || ''; } catch (e) { return ''; } };

  /* ---- רשימת המפגשים: אותה שורה כמו בטבלאות של הרפתקה, מתוך /meetings (עם מפגשים שעברו) ---- */
  var mcache = null, mcacheAt = 0, mpend = null;
  function loadMeetings() {
    if (mcache && Date.now() - mcacheAt < 4000) return Promise.resolve(mcache);
    if (mpend) return mpend;
    mpend = roster('/meetings?limit=100&past=10').then(async function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      var d = await r.json();
      mcache = (d.meetings || []).map(function (m) {
        return { id: m.id, meeting_date: m.date, meeting_time: String(m.time || '') + ':00', name: m.name || null, max_participants: m.capacity == null ? null : m.capacity, directions: null,
          price_tiers: m.price_tiers || null, image_url: m.image || null, city: m.city || null, place: m.place || null, type_id: null };
      });
      mcacheAt = Date.now(); return mcache;
    }).finally(function () { mpend = null; });
    return mpend;
  }
  function meetingsQuery(path) {
    var q = new URLSearchParams(path.split('?')[1] || ''), rows;
    return loadMeetings().then(function (all) {
      rows = all.slice();
      var d = q.get('meeting_date');
      if (d && d.indexOf('gte.') === 0) rows = rows.filter(function (m) { return m.meeting_date >= d.slice(4); });
      if (d && d.indexOf('lt.') === 0) rows = rows.filter(function (m) { return m.meeting_date < d.slice(3); });
      var id = q.get('id'); if (id && id.indexOf('eq.') === 0) rows = rows.filter(function (m) { return m.id === id.slice(3); });
      var desc = /meeting_date\.desc/.test(q.get('order') || '');
      rows.sort(function (a, b) { var x = (a.meeting_date + a.meeting_time).localeCompare(b.meeting_date + b.meeting_time); return desc ? -x : x; });
      var lim = parseInt(q.get('limit') || '0', 10); if (lim > 0) rows = rows.slice(0, lim);
      return reply(rows);
    }).catch(function () { return reply([], 502); });
  }

  /* ---- הרשמת אורח בשני שלבים ---- */
  async function signupPhone(b) {
    var body = { phone: b.p_phone };
    if (b.p_meeting) body.meeting_id = b.p_meeting;
    if (b.p_src) body.source_code = b.p_src;
    var r = await roster('/signup/phone', { method: 'POST', body: JSON.stringify(body) });
    if (!r.ok) { var f = await errField(r); return f === 'phone' ? reply({ status: 'invalid_phone' }) : reply({ error: 'roster_' + r.status }, 500); }
    var j = await r.json(); setTok(j.participant_token || '');
    return reply(j.complete ? { status: 'exists', registered: !!j.registered, age: null } : { status: 'need_details', registered: !!j.registered });
  }
  async function signupComplete(b) {
    var body = { participant_token: getTok(), first_name: b.p_first, last_name: b.p_last, age: b.p_age, gender: b.p_gender };
    var r = await roster('/signup/complete', { method: 'POST', body: JSON.stringify(body) });
    if (r.ok) return reply('ok');
    var f = await errField(r); return reply(FIELD_CODE[f] || 'error');
  }
  async function reportToken(b) {
    var r = await roster('/payments/click', { method: 'POST', body: JSON.stringify({ participant_token: getTok(), meeting_id: b.p_meeting }) });
    return r.ok ? reply('ok') : reply({ error: 'roster_' + r.status }, 400);
  }

  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : (input && input.url) || '';
    if (url.indexOf(SB) !== 0) return real(input, init);
    var path = url.slice(SB.length);
    init = init || {};

    if (path.indexOf('/auth/v1/') === 0) {   // התחברות: אותו מסלול, השרת של floa
      var h = headersOf(init); h.apikey = R.authKey;
      return real(R.authUrl + path, Object.assign({}, init, { headers: h }));
    }
    if (path.indexOf('/rest/v1/rpc/') === 0) {
      var name = path.slice('/rest/v1/rpc/'.length).split('?')[0], b = bodyOf(init);
      if (ME[name]) {
        if (b.p_as) return Promise.resolve(reply({ status: 'auth' }));   // צפייה כמשתתף עוד לא נתמכת מול רוסטר
        var nb = Object.assign({ p_slug: R.slug || 'harpatka' }, b); delete nb.p_as; delete nb.p_src;
        var hh = headersOf(init); hh.apikey = R.authKey; hh['content-profile'] = R.profile || 'roster-test'; hh['accept-profile'] = R.profile || 'roster-test';
        var src = b.p_src, prof = R.profile || 'roster-test';
        return real(R.authUrl + '/rest/v1/rpc/' + ME[name], Object.assign({}, init, { headers: hh, body: JSON.stringify(nb) })).then(function (res) {
          if (src && (name === 'harpatka_me_phone' || name === 'harpatka_me_register' || name === 'harpatka_me_register_src')) {   // מאיזה קוד (?s=) הגיע: נקבע רק למשתתף שעוד אין לו
            var h2 = Object.assign({}, hh); h2['content-type'] = 'application/json';
            real(R.authUrl + '/rest/v1/rpc/me_source', { method: 'POST', headers: h2, body: JSON.stringify({ p_slug: R.slug || 'harpatka', p_code: src }) }).catch(function () {});
          }
          return res;
        });
      }
      if (name === 'harpatka_signup_phone') return signupPhone(b);
      if (name === 'harpatka_signup_complete') return signupComplete(b);
      if (name === 'harpatka_report_payment_token') return reportToken(b);
      if (name === 'harpatka_me_claim' || name === 'harpatka_me_claim_token') return Promise.resolve(reply('none'));   // החיבור למשתתף נעשה לפי טלפון (me_phone)
      return real(input, init);   // כל השאר (למשל harpatka_signup הישן) ממשיך כמו שהיה
    }
    if (path.indexOf('/rest/v1/harpatka_meetings') === 0) return meetingsQuery(path);
    if (path.indexOf('/rest/v1/harpatka_meeting_types') === 0 || path.indexOf('/rest/v1/harpatka_public_settings') === 0) return Promise.resolve(reply([]));
    return real(input, init);
  };
})();
