-- מחיקת תבניות מיילים שלא נשלחים (2.11.26, לבקשת בעל האתר): של לוח השיתופים, שהוסר מהאתר, ו-payment_partial, כי על תשלום חלקי לא שולחים מייל. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-drop-board.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-drop-board.sql | supabase db query --linked
-- * הפונקציות והטריגרים של הלוח נשארו. אם הם ינסו לשלוח, harpatka_send_mail לא נכשלת ופשוט לא שולחת, כי אין תבנית.
-- * להחזרת הלוח צריך להחזיר גם את התבניות: מהגיבוי של אותו יום, או מ-admin/mail-redesign.sql ומקובצי המיילים של הלוח ב-admin/ (הם בעיצוב הישן).
delete from __S__.harpatka_mail_templates
where key in ('comment_published', 'reply_published', 'first_pending', 'post_published', 'post_pending', 'post_edit', 'post_edited', 'member_pending', 'member_approved', 'payment_partial');
