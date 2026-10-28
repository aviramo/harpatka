/* שדות הפרטים האישיים: אלמנט אחד לכל הטפסים באתר (פופאפ ההרשמה והשארת פרטים, הרשמה ועריכת פרטים באזור האישי).
   שם פרטי, שם משפחה, טלפון, גיל ומגדר: כולם חובה, עם אותן בדיקות ואותן הודעות שגיאה.
   תכונות autocomplete (given-name, family-name, tel, sex) גורמות לדפדפן (כרום וכו') להציע בעמידה על שדה את הפרטים השמורים בחשבון גוגל ולמלא אוטומטית; הגיל נשאר ידני.
   שימוש: PersonForm.html('first', opts) לכל שדה (הפריסה בעמוד), PersonForm.bind(root), PersonForm.validate(root), PersonForm.serverError(root, code), PersonForm.fill(root, values). */
(function () {
  var LABEL = { first: 'שם פרטי', last: 'שם משפחה', phone: 'טלפון', age: 'גיל', gender: 'מגדר' };
  var AC = { first: 'given-name', last: 'family-name', phone: 'tel', age: 'off', gender: 'sex' };
  var NAME = { first: 'given-name', last: 'family-name', phone: 'tel', age: 'age', gender: 'sex' };
  var MSG = { name: 'נא למלא שם פרטי ושם משפחה', phone: 'מספר לא תקין', age: 'גיל לא תקין (18 עד 99)', gender: 'נא לבחור מגדר' };
  var ERR_FOR = { first: 'name', last: 'name', phone: 'phone', age: 'age', gender: 'gender' };

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  /* מספר ישראלי שמתחיל ב-0, או מספר עם + (E.164); מחזיר +972... או '' כשלא תקין. זהה ל-harpatka_normalize_phone ב-SQL */
  function normPhone(raw) {
    var s = String(raw || '').trim();
    if (!s) return '';
    var plus = s[0] === '+', d = s.replace(/\D/g, '');
    if (!d) return '';
    if (d.indexOf('00') === 0) { plus = true; d = d.slice(2); }
    var IL = /^(5\d{8}|7\d{8}|[23489]\d{7})$/;
    if (plus) {
      if (d.indexOf('9720') === 0) d = '972' + d.slice(4);
      if (d.length < 8 || d.length > 15 || d[0] === '0') return '';
      if (d.indexOf('972') === 0 && !IL.test(d.slice(3))) return '';
      return '+' + d;
    }
    if (d[0] === '0') return IL.test(d.slice(1)) ? '+972' + d.slice(1) : '';
    return '';
  }

  /* html(kind, opts): kind = first | last | phone | age | gender.
     opts: id (מזהה האלמנט), cls (מחלקת השדה), selCls (מחלקות הרשימה), label (true: תווית מעל השדה, אחרת פלייסהולדר),
           value (ערך התחלתי), attr (תכונות נוספות), autofocus */
  function html(kind, o) {
    o = o || {};
    var id = o.id || ('pf' + kind), cls = o.cls || '', ph = LABEL[kind], v = o.value == null ? '' : o.value;
    var lab = o.label ? '<label for="' + id + '">' + ph + '</label>' : '';
    var common = ' id="' + id + '" data-pf="' + kind + '" name="' + NAME[kind] + '" autocomplete="' + AC[kind] + '" aria-label="' + ph + '" required' + (o.autofocus ? ' data-autofocus' : '') + (o.attr ? ' ' + o.attr : '');
    if (kind === 'gender') {
      return lab + '<select' + common + ' class="' + esc(o.selCls || cls) + '"><option value=""' + (v ? '' : ' selected') + ' disabled>' + (o.label ? 'בחירה' : ph) + '</option><option value="male"' + (v === 'male' ? ' selected' : '') + '>זכר</option><option value="female"' + (v === 'female' ? ' selected' : '') + '>נקבה</option></select>';
    }
    var type = kind === 'phone' ? 'tel' : kind === 'age' ? 'number' : 'text';
    var extra = kind === 'phone' ? ' inputmode="tel" dir="ltr" maxlength="24"' : kind === 'age' ? ' inputmode="numeric" min="18" max="99"' : ' maxlength="40"';
    return lab + '<input type="' + type + '"' + common + extra + ' class="' + esc(cls) + '"' + (o.label ? '' : ' placeholder="' + ph + '"') + (v !== '' ? ' value="' + esc(v) + '"' : '') + '>';
  }
  /* הודעת שגיאה: name (לשני שמות), phone, age, gender */
  function err(kind, cls) { return '<div data-pf-err="' + kind + '" class="' + (cls || 'pf-err') + '" role="alert"></div>'; }

  function el(root, kind) { return root.querySelector('[data-pf="' + kind + '"]'); }
  function setErr(root, kind, msg) {
    var box = root.querySelector('[data-pf-err="' + kind + '"]'); if (box) box.textContent = msg || '';
    (kind === 'name' ? ['first', 'last'] : [kind]).forEach(function (k) { var e = el(root, k); if (e) e.classList.toggle('bad', !!msg); });
  }
  function clearAll(root) { ['name', 'phone', 'age', 'gender'].forEach(function (k) { setErr(root, k, ''); }); }

  /* מנקה את השגיאה של שדה כשמתחילים לתקן אותו */
  function bind(root) {
    ['first', 'last', 'phone', 'age', 'gender'].forEach(function (k) {
      var e = el(root, k); if (!e || e.dataset.pfBound) return; e.dataset.pfBound = '1';
      e.addEventListener(k === 'gender' ? 'change' : 'input', function () { setErr(root, ERR_FOR[k], ''); });
    });
  }

  function read(root) {
    var g = function (k) { var e = el(root, k); return e ? String(e.value || '').trim() : ''; };
    var first = g('first').replace(/\s+/g, ' '), last = g('last').replace(/\s+/g, ' '), raw = g('phone'), ageS = g('age');
    return { first: first, last: last, phoneRaw: raw, phone: normPhone(raw), age: ageS === '' ? NaN : parseInt(ageS, 10), gender: g('gender') || null };
  }

  /* בדיקה אחת לכולם: כל השדות חובה. מחזיר { ok, v } ומציג שגיאות ליד השדות */
  function validate(root) {
    var v = read(root), ok = true;
    if (v.first.length < 2 || v.last.length < 2) { setErr(root, 'name', MSG.name); var f = el(root, 'first'), l = el(root, 'last'); if (f) f.classList.toggle('bad', v.first.length < 2); if (l) l.classList.toggle('bad', v.last.length < 2); ok = false; } else setErr(root, 'name', '');
    if (!v.phone) { setErr(root, 'phone', MSG.phone); ok = false; } else setErr(root, 'phone', '');
    if (!(v.age >= 18 && v.age <= 99)) { setErr(root, 'age', MSG.age); ok = false; } else setErr(root, 'age', '');
    if (v.gender !== 'male' && v.gender !== 'female') { setErr(root, 'gender', MSG.gender); ok = false; } else setErr(root, 'gender', '');
    return { ok: ok, v: v };
  }

  /* קוד שגיאה מהשרת ← הודעה ליד השדה המתאים. מחזיר true אם טופל */
  function serverError(root, code) {
    var map = { invalid_name: 'name', invalid_phone: 'phone', invalid_age: 'age', invalid_gender: 'gender' };
    if (!map[code]) return false;
    setErr(root, map[code], MSG[map[code]]); return true;
  }

  /* ממלא ערכים (עריכת פרטים, או שם מחשבון גוגל). שדה שכבר יש בו ערך לא נדרס אלא אם force */
  function fill(root, vals, force) {
    var set = function (k, v) { var e = el(root, k); if (e && v != null && v !== '' && (force || !e.value)) e.value = v; };
    set('first', vals.first); set('last', vals.last); set('phone', vals.phone); set('age', vals.age); set('gender', vals.gender);
  }

  window.normPhone = normPhone;
  window.PersonForm = { html: html, err: err, bind: bind, read: read, validate: validate, serverError: serverError, fill: fill, setErr: setErr, clearAll: clearAll, normPhone: normPhone, MSG: MSG };
})();
