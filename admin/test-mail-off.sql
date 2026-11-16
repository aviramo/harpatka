-- סביבת הבדיקות בלבד (סכמת test): המיילים של הרפתקה כבויים. כל המיילים נשלחים מרוסטר (Worker floa-lead-test, העסק harpatka ב-roster-test).
-- הגדרה מקורית (לחזרה): harpatka-backups/2026-11-16-test-harpatka_send_mail-before.json
create or replace function test.harpatka_send_mail(p_key text, p_vars jsonb default '{}'::jsonb, p_to text default null, p_extra jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path to 'test', 'public' as $fn$
begin
  return;   -- בלי שליחה ובלי יומן: המיילים של המערכת יוצאים מרוסטר
end $fn$;
