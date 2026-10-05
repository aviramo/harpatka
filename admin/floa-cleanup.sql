-- ==========================================================================
-- ניקוי: מחיקת כל מה שנוצר עבור "יוצאים להרפתקה" מ-Supabase של floa.
--
-- ⚠️ להריץ ב-SQL Editor של floa (aexmnaxvahblveejsbup) רק אחרי ש:
--   1. הפרויקט החדש הוקם (admin/setup.sql) והנתונים הועברו,
--   2. האתר והדף admin/ כבר מצביעים על הפרויקט החדש ונבדקו.
-- אי אפשר לשחזר אחרי ההרצה. לא נוגע בשום דבר אחר של floa.
-- ==========================================================================

drop function if exists public.harpatka_signup(text, text, int);
drop function if exists public.harpatka_signup(text, text);
drop function if exists public.harpatka_is_admin();
drop table if exists public.harpatka_attendance cascade;
drop table if exists public.harpatka_participants cascade;
drop table if exists public.harpatka_meetings cascade;
drop table if exists public.harpatka_admins cascade;
drop function if exists public.harpatka_participants_phone_trg() cascade;
drop function if exists public.harpatka_normalize_phone(text);

notify pgrst, 'reload schema';
