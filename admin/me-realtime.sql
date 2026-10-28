-- מצב המפגשים של המשתתף בדף הבית בזמן אמת (28.10.26): כל שינוי בתשלומים, בשיוכים למפגשים ובמפגשים שולח אות ריק בערוץ ציבורי "me"
-- (בבדיקות "me-test"), בלי נתונים. הדפדפנים של משתתפים מחוברים טוענים מחדש את המצב שלהם דרך harpatka_me (שמחילה את כללי הצפייה).
-- אידמפוטנטי; להריץ על public ועל test (הסכמה מוגדרת למטה).
do $$
declare s text; topic text; t text;
begin
  foreach s in array array['public', 'test'] loop
    topic := case when s = 'public' then 'me' else 'me-test' end;
    execute format($f$
      create or replace function %I.harpatka_me_signal() returns trigger language plpgsql security definer set search_path = %I as $b$
      begin
        perform realtime.send('{}'::jsonb, 'change', %L, false);
        return null;
      exception when others then return null;
      end $b$
      $f$, s, s, topic);
    execute format('revoke all on function %I.harpatka_me_signal() from public, anon, authenticated', s);
    foreach t in array array['harpatka_payments', 'harpatka_attendance', 'harpatka_meetings'] loop
      execute format('drop trigger if exists harpatka_me_signal on %I.%I', s, t);
      execute format('create trigger harpatka_me_signal after insert or update or delete on %I.%I for each statement execute function %I.harpatka_me_signal()', s, t, s);
    end loop;
  end loop;
end $$;
