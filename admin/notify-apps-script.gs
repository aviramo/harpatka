/**
 * יוצאים להרפתקה: שולח מיילים גנרי (Google Apps Script).
 *
 * הסקריפט לא יודע כלום על תוכן המיילים: הוא מקבל מבסיס הנתונים נמען, נושא ו-HTML מוכן ושולח.
 * הטמפלטים (העיצוב והטקסט) נמצאים בטבלה harpatka_mail_templates ב-Supabase, ולכן טמפלט חדש
 * לא דורש שינוי כאן ולא פרסום מחדש.
 *
 * הקמה (פעם אחת):
 * 1. https://script.google.com -> הפרויקט הקיים -> למחוק את הקוד ולהדביק את כל הקובץ הזה.
 * 2. Project Settings -> Script properties: NOTIFY_TOKEN = אותו טוקן שכבר שמור (לא משנים).
 * 3. Deploy -> Manage deployments -> העיפרון (Edit) -> Version: New version -> Deploy. (אותו URL.)
 * 4. אפשר להריץ testSend מהעורך לבדיקה.
 */
const DEFAULT_TO = 'ofir.aviram@gmail.com,luriahadar@gmail.com';   // כשלא נקבע נמען בטמפלט/בהגדרות

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    const token = PropertiesService.getScriptProperties().getProperty('NOTIFY_TOKEN');
    if (!token || d.token !== token) return ContentService.createTextOutput('forbidden');
    if (!d.html || !d.subject) return ContentService.createTextOutput('bad request');
    const to = Array.isArray(d.to) ? d.to.join(',') : (d.to || DEFAULT_TO);
    const text = String(d.text || d.html).replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    MailApp.sendEmail({ to: to, subject: d.subject, body: text, htmlBody: d.html, name: d.name || 'יוצאים להרפתקה', replyTo: d.reply_to || undefined });
    return ContentService.createTextOutput('ok');
  } catch (err) {
    return ContentService.createTextOutput('error');
  }
}

/** בדיקה ידנית מתוך העורך (נדרש גם כדי לאשר הרשאות שליחה) */
function testSend() {
  MailApp.sendEmail({ to: DEFAULT_TO, subject: 'בדיקת מערכת המיילים', body: 'בדיקה', htmlBody: '<div dir="rtl" style="font-family:Arial">בדיקת מערכת המיילים: עובד</div>', name: 'יוצאים להרפתקה' });
}
