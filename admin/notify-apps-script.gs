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
  const meeting = d.meeting_date ? (d.meeting_date + (d.meeting_time ? ' בשעה ' + d.meeting_time : '')) : 'אין מפגש קרוב';
  const when = Utilities.formatDate(new Date(d.created_at || Date.now()), 'Asia/Jerusalem', 'dd.MM.yyyy HH:mm');
  const link = ADMIN_URL + (d.meeting_id || d.participant_id
    ? '?' + [d.meeting_id ? 'm=' + d.meeting_id : '', d.participant_id ? 'p=' + d.participant_id : ''].filter(Boolean).join('&') : '');
  const body = [
    'נרשם/ה משתתף/ת חדש/ה דרך האתר:',
    '',
    'שם: ' + d.name,
    'טלפון: ' + d.phone,
    'גיל: ' + d.age,
    'מפגש: ' + meeting,
    'זמן ההרשמה: ' + when,
    '',
    'וואטסאפ: https://wa.me/' + digits,
    'הפרטים בדף הניהול (במפגש הזה): ' + link
  ].join('\n');
  MailApp.sendEmail({ to: TO, subject: 'הרשמה חדשה מהאתר: ' + d.name, body: body, name: 'יוצאים להרפתקה' });
}

/** בדיקה ידנית מתוך העורך (גם נדרש להרצה ראשונה כדי לאשר הרשאות) */
function testSend() {
  send_({ name: 'בדיקה', phone: '+972500000000', age: 44, meeting_date: '2026-10-25', meeting_time: '20:00', created_at: new Date().toISOString() });
}
