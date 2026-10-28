-- זמן אמת בכל המערכת (28.10.26): (1) כל הטבלאות שדף הניהול קורא מהן נכנסות ל-publication של Realtime (גם הגדרות, דרכי תשלום, כספים ויומן הכספים);
-- (2) אות "me" (בבדיקות "me-test") נשלח גם על שינוי בפרטי משתתפים ובחיבורי האזור האישי, לא רק על תשלומים, שיוכים ומפגשים;
-- (3) אות חדש "meetings" (בבדיקות "meetings-test") על שינוי במפגשים ובהגדרות הציבוריות, כדי שגם מבקר לא מחובר בדף הבית יראה מפגשים בזמן אמת.
-- אידמפוטנטי; להריץ פעם אחת (מטפל בשתי הסכמות, public ו-test).
do $$
declare s text; t text; topic text; mtopic text;
begin
  foreach s in array array['public', 'test'] loop
    foreach t in array array['harpatka_admin_prefs', 'harpatka_pay_methods', 'harpatka_public_settings', 'harpatka_finance_log', 'harpatka_sources', 'harpatka_members'] loop
      if to_regclass(format('%I.%I', s, t)) is not null and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = s and tablename = t) then
        execute format('alter publication supabase_realtime add table %I.%I', s, t);
      end if;
    end loop;
    topic := case when s = 'public' then 'me' else 'me-test' end;
    mtopic := case when s = 'public' then 'meetings' else 'meetings-test' end;
    foreach t in array array['harpatka_participants', 'harpatka_members'] loop
      if to_regclass(format('%I.%I', s, t)) is not null then
        execute format('drop trigger if exists harpatka_me_signal on %I.%I', s, t);
        execute format('create trigger harpatka_me_signal after insert or update or delete on %I.%I for each statement execute function %I.harpatka_me_signal()', s, t, s);
      end if;
    end loop;
    execute format($f$
      create or replace function %I.harpatka_meetings_signal() returns trigger language plpgsql security definer set search_path = %I as $b$
      begin
        perform realtime.send('{}'::jsonb, 'change', %L, false);
        return null;
      exception when others then return null;
      end $b$
      $f$, s, s, mtopic);
    execute format('revoke all on function %I.harpatka_meetings_signal() from public, anon, authenticated', s);
    foreach t in array array['harpatka_meetings', 'harpatka_public_settings'] loop
      if to_regclass(format('%I.%I', s, t)) is not null then
        execute format('drop trigger if exists harpatka_meetings_signal on %I.%I', s, t);
        execute format('create trigger harpatka_meetings_signal after insert or update or delete on %I.%I for each statement execute function %I.harpatka_meetings_signal()', s, t, s);
      end if;
    end loop;
  end loop;
end $$;
