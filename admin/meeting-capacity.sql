-- מקסימום משתתפים לכל מפגש + מדרגות המחיר גלויות לציבור (לרצועת המפגשים בעמוד הבית). אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists max_participants integer default 40', s);
    execute format('alter table %I.harpatka_meetings drop constraint if exists harpatka_meetings_max_chk', s);
    execute format('alter table %I.harpatka_meetings add constraint harpatka_meetings_max_chk check (max_participants is null or max_participants between 1 and 500)', s);
    -- מדרגות המחיר הן מידע ציבורי (מוצגות באתר): קריאה בלבד למבקרים
    execute format('drop policy if exists "harpatka public read tiers" on %I.harpatka_price_tiers', s);
    execute format('create policy "harpatka public read tiers" on %I.harpatka_price_tiers for select to anon using (true)', s);
  end loop;
end $$;
