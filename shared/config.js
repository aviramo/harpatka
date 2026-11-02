/* הגדרות משותפות לכל העמודים (עמוד הבית, v6, ביודנסה). עמוד יכול לדרוס ערך אחרי טעינת הקובץ, למשל CONFIG.hadarMessage */
const CONFIG = {
  googleLogin: true,   // מתג: כניסה עם גוגל לציבור (אזור אישי, "נרשמתם בעבר", זיהוי משתתף מחובר). כבוי זמנית (30.10.26): ההרשמה רגילה עם הפרטים המלאים. להחזרה: true (ואז הגרסה החזרה: git tag google-login-enabled)
  googleClientId: '459432002435-349ppd8r1qqe9tkcdm2v3f6rpp48i1ni.apps.googleusercontent.com',   // מזהה ה-OAuth client של גוגל (ציבורי, אותו אחד ש-Supabase משתמש בו) לשכבת הכניסה של גוגל מעל הדף (One Tap)
  supabaseUrl: 'https://ezakarwqstnldqixgreb.supabase.co',     // Supabase הייעודי של הפרויקט (harpatka_meetings / harpatka_signup)
  supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6YWthcndxc3RubGRxaXhncmViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMTA3MzIsImV4cCI6MjEwNjc4NjczMn0.Bg0eFBC4zKjyJc5kBw3wLgSP-PkxLFVv3o7-4YUdq4c',                  // מפתח ציבורי (anon)
  whatsappOfir: '972587078708',                   // מספר הנייד של אופיר (פורמט בינ"ל, בלי +)
  whatsappHadar: '972546163012',                  // מספר הנייד של הדר — יעד כל כפתורי "אני רוצה להצטרף"
  hadarMessage: 'היי הדר, הגעתי אליכם דרך האתר',
  ofirMessage: 'היי אופיר, הגעתי אליכם דרך האתר',
  updatesGroupLink: 'https://chat.whatsapp.com/HPBClkrbondA3JlQyOvseI',            // קבוצת העדכונים עד גיל 50
  updatesGroup50PlusLink: 'https://chat.whatsapp.com/DB7zVc2NdVXEquZCC6PpUP',      // קבוצת העדכונים גיל 50 ומעלה
  payboxLink: 'https://links.payboxapp.com/zwi4JG24Y6b',
  sheetsEndpoint: 'https://script.google.com/macros/s/AKfycbzTGo8SNjyF-xJsn08PXWrYt6EdkZOlmOCXeeFnlMHvg7uyMxXR6i8IoemuiBJTZE-EPQ/exec',
  pixelId: '429806621602468',
  meetingFallback: { date: '2026-10-25', time: '20:00' },   // המפגש הקרוב אם הטעינה מבסיס הנתונים נכשלת
  meetingPlace: 'הרצליה',
  /* פרטי מפגש: רכיב אחד לפופאפי ההרשמה ולאזור האישי (עיצוב: shared/meeting-box.css), באותו מבנה כמו כרטיס המפגש בדף הבית. מציג רק מה שהוזן למפגש. extra: תוכן נוסף בתוך המסגרת */
  meetingBox: (m, extra) => {
    const esc = (v) => String(v == null ? '' : v).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    const [, mo, d] = String(m.date).split('-').map(Number), wd = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'][new Date(m.date + 'T12:00:00Z').getUTCDay()];
    const when = 'יום ' + wd + ' ' + d + '.' + mo + (m.time ? ' · ' + String(m.time).slice(0, 5) : ''), where = [m.city, m.place].map((x) => String(x || '').trim()).filter(Boolean).join(' · '), n = Number(m.max) || 0;
    const ppl = n ? '<span class="mbox-ppl" aria-label="' + n + ' משתתפים" title="' + n + ' משתתפים">' + (where ? '<i aria-hidden="true">·</i>' : '') + '<b aria-hidden="true">' + n + '</b><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/></svg></span>' : '';
    return '<div class="mbox">' + (m.img ? '<img class="mbox-img" src="' + esc(m.img) + '" alt="" decoding="async">' : '') + '<div class="mbox-in">' + (m.name ? '<div class="mbox-name">' + esc(m.name) + '</div>' : '') + '<div class="mbox-when">' + esc(when) + '</div>' + (where || n ? '<div class="mbox-where">' + esc(where) + ppl + '</div>' : '') + (extra || '') + '</div></div>';
  },
};
