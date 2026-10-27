-- מבנה מדרגות חדש לכל מפגש: price_tiers = {"base": 60, "steps": [{"days": 2, "price": 80}], "final": 100 או null}
-- base = המחיר הרגיל (מתחילת ההרשמה); כל שלב = "החל מ-N ימים לפני המפגש"; final = מחיר ביום המפגש (אופציונלי).
-- ממיר את המבנה הקודם (מערך [{days, price}] שבו המחיר חל כשנשארו לפחות days ימים). אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text; r record; arr jsonb[]; k int; d int; steps jsonb;
begin
  foreach s in array array['public', 'test'] loop
    for r in execute format('select id, price_tiers from %I.harpatka_meetings where jsonb_typeof(price_tiers) = ''array''', s) loop
      select array_agg(e order by (e->>'days')::int desc) into arr from jsonb_array_elements(r.price_tiers) e;
      steps := '[]'::jsonb;
      for k in 2 .. coalesce(array_length(arr, 1), 0) loop
        d := (arr[k-1]->>'days')::int - 1;
        if d >= 1 then steps := steps || jsonb_build_object('days', d, 'price', (arr[k]->>'price')::int); end if;
      end loop;
      execute format('update %I.harpatka_meetings set price_tiers = $1 where id = $2', s)
        using jsonb_build_object('base', (arr[1]->>'price')::int, 'steps', steps, 'final', null), r.id;
    end loop;
  end loop;
end $$;
