-- בלי המושג "חינם" (2.11.26): המצב של מפגש בלי תשלום נקרא "לא לתשלום" (no_pay), ו"לא שולם" (סגירה בלי תשלום) אוחד איתו.
-- כאן רק הניסוח בפונקציות שכותבות הערות; הנתונים לא משתנים. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/no-pay-wording.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/no-pay-wording.sql | supabase db query --linked
do $do$
declare r record; d text;
begin
  for r in
    select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = '__S__' and p.proname in ('harpatka_att_notes', 'harpatka_pay_status', 'harpatka_status_label')
  loop
    d := pg_get_functiondef(r.oid);
    if d like '%חינם%' then
      d := replace(d, $q$' סומן כחינם'$q$, $q$' סומן לא לתשלום'$q$);
      d := replace(d, $q$'החינם בוטל למפגש '$q$, $q$'חזרה לתשלום למפגש '$q$);
      d := replace(d, $q$'חינם'$q$, $q$'לא לתשלום'$q$);
      d := replace(d, 'סימון "חינם"', 'סימון "לא לתשלום"');
      if d like '%חינם%' then raise exception 'wording left in %', r.oid; end if;
      execute d;
    end if;
  end loop;
end $do$;
notify pgrst, 'reload schema';
