-- מדרגות מחיר לכל מפגש (במקום הגדרה גלובלית): עמודה price_tiers (jsonb) במפגש, בצורה [{"days":4,"price":80},{"days":0,"price":100}].
-- אידמפוטנטי; להריץ על public ועל test. הטבלה הגלובלית harpatka_price_tiers נמחקת רק בשלב נפרד (admin/drop-global-tiers.sql) אחרי שהקוד עבר.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists price_tiers jsonb', s);
    -- מפגש קיים בלי מדרגות מקבל את ההעתק של המדרגות הגלובליות הנוכחיות
    execute format($f$update %I.harpatka_meetings set price_tiers = (select coalesce(jsonb_agg(jsonb_build_object('days', days, 'price', price) order by days desc), '[]'::jsonb) from %I.harpatka_price_tiers) where price_tiers is null$f$, s, s);
  end loop;
end $$;
