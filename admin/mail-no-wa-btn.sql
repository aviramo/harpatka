-- בלי כפתור "שליחת וואטסאפ" במיילים למנהלים (3.11.26, לבקשת בעל האתר). בטוח להריץ שוב.
--   sed 's/__S__/test/g' admin/mail-no-wa-btn.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-no-wa-btn.sql | supabase db query --linked
-- * הקישור למשתתף בדף הניהול נשאר, ודרכו מגיעים לוואטסאפ. הפרמטר wa_link שהפונקציות שולחות נשאר בלי שימוש.
update __S__.harpatka_mail_templates
   set html = regexp_replace(html, '<a href="\{\{wa_link\}\}"[^>]*>[^<]*</a>\s*', '', 'g')
 where html like '%{{wa_link}}%';
