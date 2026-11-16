-- אסור שמשתתף יבטל לעצמו שמירת מקום (החלטת הבעלים, 17.11.26): הפונקציה כבר לא מבטלת כלום, מחזירה תמיד 'forbidden'.
-- ביטול נעשה רק על ידי מנהל, מדף הניהול. החתימה והתשובה (טקסט) נשארות כדי שקריאה ישנה לא תישבר.
-- לגרסה לפני השינוי: harpatka-backups/public-harpatka_me_unregister-before.sql
create or replace function public.harpatka_me_unregister(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
begin
  return 'forbidden';
end $$;
