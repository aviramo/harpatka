-- ==========================================================================
-- זמן אמת בדף הניהול: מוסיף את הטבלאות ל-publication של Supabase Realtime.
-- להריץ פעם אחת ב-SQL Editor של הפרויקט (אפשר להריץ שוב בלי נזק).
-- הרשאות נשמרות: Realtime מכבד RLS, ורק מנהלים מחוברים מקבלים שינויים.
-- ==========================================================================
do $$
declare t text;
begin
  foreach t in array array['harpatka_participants', 'harpatka_meetings', 'harpatka_attendance'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
