-- קישורי ניווט לכל מפגש (גוגל מפות ווייז), מוצגים ברצועת המפגשים בעמוד הבית. אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists maps_url text', s);
    execute format('alter table %I.harpatka_meetings add column if not exists waze_url text', s);
  end loop;
end $$;
