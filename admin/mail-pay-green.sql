-- כפתור התשלום במיילים בירוק, כמו כפתור התשלום באתר (2.11.26). אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-pay-green.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-pay-green.sql | supabase db query --linked
-- רק מיילים שהכפתור שלהם מוביל לתשלום: נרשמת ונשאר לשלם, תשלום חלקי, ודיווח תשלום שנדחה. בכל אחד יש רקע כתום אחד בלבד, של הכפתור.
update __S__.harpatka_mail_templates set html = replace(html, 'background:#C8411B', 'background:#4E7D2C')
where key in ('meeting_registered', 'payment_partial', 'payment_rejected');
