-- צפייה כמשתתף (p_as) היא לקריאה בלבד: מנהל לא מבצע פעולות בשם משתתף, באזור האישי ובדף הבית.
-- כל פונקציית כתיבה שמקבלת p_as מסרבת בתחילתה. harpatka_me (קריאה) לא משתנה. אידמפוטנטי.
-- הרצה: sed 's/__S__/test/g' admin/view-as-readonly.sql (ובקידום לאמת: public).
-- אחרי הרצה חוזרת של admin/test-site.sql (מעתיק פונקציות מ-public) להריץ שוב על test.
do $$
declare
  sch text := '__S__'; r record; d text; n int := 0;
begin
  for r in
    select p.oid, p.proname from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = sch and pg_get_function_identity_arguments(p.oid) like '%p_as%'
      and p.proname in ('harpatka_me_register', 'harpatka_me_unregister', 'harpatka_me_update', 'harpatka_me_complete', 'harpatka_me_report_payment', 'harpatka_me_pay_credit')
  loop
    d := pg_get_functiondef(r.oid);
    if position('view_only' in d) > 0 then continue; end if;
    d := regexp_replace(d, E'\nbegin\r?\n', E'\nbegin\n  if p_as is not null then raise exception ''view_only''; end if;   -- צפייה כמשתתף לקריאה בלבד\n');
    if position('view_only' in d) = 0 then raise exception 'no begin in %', r.proname; end if;
    execute d; n := n + 1;
  end loop;
  raise notice 'patched %', n;
end $$;
