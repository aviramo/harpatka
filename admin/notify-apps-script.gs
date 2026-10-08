/**
 * יוצאים להרפתקה: שליחת מייל על הרשמה חדשה מהאתר (מייל אחד לשני נמענים).
 *
 * הקמה (פעם אחת):
 * 1. https://script.google.com -> New project -> למחוק את הקוד ולהדביק את כל הקובץ הזה.
 * 2. Project Settings (גלגל שיניים) -> Script properties -> Add: NOTIFY_TOKEN = סיסמה אקראית ארוכה.
 * 3. להריץ פעם אחת את testSend (כפתור Run) ולאשר הרשאות (שליחת מייל). יגיע מייל בדיקה.
 * 4. Deploy -> New deployment -> Web app: Execute as = Me, Who has access = Anyone -> Deploy -> להעתיק את ה-URL.
 * 5. ב-Supabase: להריץ את השורה insert into harpatka_settings (בסוף admin/notify.sql) עם ה-URL והטוקן.
 * שינוי נמענים או נוסח: לערוך כאן ולעשות Deploy -> Manage deployments -> Edit -> New version.
 */
const TO = 'ofir.aviram@gmail.com,luriahadar@gmail.com';
const ADMIN_URL = 'https://harpatka.co.il/admin/';

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    const token = PropertiesService.getScriptProperties().getProperty('NOTIFY_TOKEN');
    if (!token || d.token !== token) return ContentService.createTextOutput('forbidden');
    send_(d);
    return ContentService.createTextOutput('ok');
  } catch (err) {
    return ContentService.createTextOutput('error');
  }
}

function send_(d) {
  const digits = String(d.phone || '').replace(/\D/g, '');
  const meeting = d.meeting_date ? (d.meeting_date.split('-').reverse().join('.') + (d.meeting_time ? ' · ' + d.meeting_time : '')) : 'אין מפגש קרוב';
  const when = Utilities.formatDate(new Date(d.created_at || Date.now()), 'Asia/Jerusalem', 'dd.MM.yyyy HH:mm');
  const link = ADMIN_URL + (d.meeting_id || d.participant_id
    ? '?' + [d.meeting_id ? 'm=' + d.meeting_id : '', d.participant_id ? 'p=' + d.participant_id : ''].filter(Boolean).join('&') : '');
  const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const row = (k, v) => '<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px;width:34%">' + k + '</td>' +
    '<td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">' + v + '</td></tr>';
  const btn = (href, bg, text) => '<a href="' + href + '" style="display:block;background:' + bg + ';color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">' + text + '</a>';
  const html =
    '<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">' +
    '<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">' +
      '<div style="background:#C96F52;color:#ffffff;padding:20px 24px">' +
        '<div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div>' +
        '<div style="font-size:22px;font-weight:bold;margin-top:4px">הרשמה חדשה מהאתר</div>' +
      '</div>' +
      '<div style="padding:22px 24px 26px">' +
        '<div style="font-size:26px;font-weight:bold;color:#3F382F;margin-bottom:14px">' + esc(d.name) + '</div>' +
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">' +
          row('טלפון', '<span dir="ltr" style="unicode-bidi:embed">' + esc(d.phone) + '</span>') +
          row('גיל', esc(d.age)) +
          (d.gender ? row('מגדר', d.gender === 'male' ? 'זכר' : 'נקבה') : '') +
          row('מפגש', esc(meeting)) +
          row('נרשם/ה ב', esc(when)) +
        '</table>' +
        btn('https://wa.me/' + digits, '#25A55F', 'שליחת וואטסאפ') +
        btn(link, '#C96F52', 'הפרטים בדף הניהול') +
      '</div>' +
    '</div></div>';
  MailApp.sendEmail({ to: TO, subject: 'הרשמה חדשה מהאתר: ' + d.name, body: 'נרשם/ה משתתף/ת חדש/ה: ' + d.name + ' ' + d.phone + ' ' + link, htmlBody: html, name: 'יוצאים להרפתקה' });
}

/** בדיקה ידנית מתוך העורך (גם נדרש להרצה ראשונה כדי לאשר הרשאות) */
function testSend() {
  send_({ name: 'בדיקה', phone: '+972500000000', age: 44, meeting_date: '2026-10-25', meeting_time: '20:00', created_at: new Date().toISOString() });
}
