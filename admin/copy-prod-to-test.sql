-- העתקת נתוני האמת (public) לסביבת הבדיקות (test), בבקשה מפורשת בלבד: דורס את כל נתוני test ולא נוגע ב-public (קריאה בלבד).
-- לא מועתקים: harpatka_settings (מפתחות סודיים), טבלאות הלוח (members, posts, likes, anon_likes), harpatka_admin_blocked. הטריגרים מושבתים בזמן ההעתקה (בלי הערות מערכת / יומן כפולים).
do $$
declare
  copy_order text[] := array['harpatka_meetings','harpatka_promoters','harpatka_participants','harpatka_statuses','harpatka_pay_methods','harpatka_public_settings','harpatka_admin_prefs','harpatka_sources','harpatka_attendance','harpatka_payments','harpatka_promoter_payments','harpatka_notes','harpatka_finance','harpatka_finance_recurring','harpatka_finance_transfers','harpatka_finance_log'];
  clear_tbls text[] := array['harpatka_posts','harpatka_likes','harpatka_anon_likes','harpatka_members','harpatka_audit'];
  t text; cols text; n bigint;
begin
  foreach t in array (copy_order || clear_tbls) loop
    if to_regclass('test.' || t) is not null then execute format('alter table test.%I disable trigger user', t); end if;
  end loop;
  -- ניקוי: כל הטבלאות (לפי סדר הפוך, עם cascade לטבלאות תלויות)
  foreach t in array (clear_tbls || (select array_agg(x order by ord desc) from unnest(copy_order) with ordinality as u(x, ord))) loop
    if to_regclass('test.' || t) is not null then execute format('truncate table test.%I restart identity cascade', t); end if;
  end loop;
  foreach t in array copy_order loop
    if to_regclass('test.' || t) is null or to_regclass('public.' || t) is null then continue; end if;
    select string_agg(format('%I', a.column_name), ', ' order by a.ordinal_position) into cols
      from information_schema.columns a join information_schema.columns b on b.table_schema = 'public' and b.table_name = t and b.column_name = a.column_name
      where a.table_schema = 'test' and a.table_name = t and a.is_generated = 'NEVER' and b.is_generated = 'NEVER';
    execute format('insert into test.%I (%s) select %s from public.%I', t, cols, cols, t);
    get diagnostics n = row_count;
    raise notice '% : % rows', t, n;
  end loop;
  foreach t in array (copy_order || clear_tbls) loop
    if to_regclass('test.' || t) is not null then execute format('alter table test.%I enable trigger user', t); end if;
  end loop;
end $$;
