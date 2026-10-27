-- עיר לכל מפגש (מוצגת בכרטיסי המפגשים בעמוד הבית ומועתקת למפגש הבא). אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists city text', s);
  end loop;
end $$;
-- סביבת הבדיקות בלבד: ערים שרירותיות כדי לראות את הצגת העיר בעמוד הבית
do $$
declare r record; cities text[] := array['הרצליה', 'תל אביב', 'רמת גן', 'חיפה', 'ירושלים']; i int := 0;
begin
  for r in select id from test.harpatka_meetings order by meeting_date loop
    update test.harpatka_meetings set city = cities[(i % array_length(cities, 1)) + 1] where id = r.id and city is null;
    i := i + 1;
  end loop;
end $$;
