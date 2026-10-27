-- שם למפגש (אופציונלי), מוצג ברצועת המפגשים בעמוד הבית ומועתק למפגש חדש. אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists name text', s);
    execute format('alter table %I.harpatka_meetings drop constraint if exists harpatka_meetings_name_chk', s);
    execute format('alter table %I.harpatka_meetings add constraint harpatka_meetings_name_chk check (name is null or char_length(name) <= 80)', s);
  end loop;
end $$;
