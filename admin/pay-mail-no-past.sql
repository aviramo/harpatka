-- מייל "התשלום התקבל" לא נשלח על מפגש שכבר עבר (2.11.26): הנוסח אומר "המקום שלך שמור" ו"איך מגיעים". זו בחירה ולא תקלה, ולכן אין אזהרה בהערה. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/pay-mail-no-past.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/pay-mail-no-past.sql | supabase db query --linked
do $do$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_pay_mail';
  if d not like '%-- מפגש שעבר: בלי מייל%' then
    d := replace(d, 'select * into mt from __S__.harpatka_meetings where id = p_mid; if not found then return false; end if;', $r$select * into mt from __S__.harpatka_meetings where id = p_mid; if not found then return false; end if;
  if mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return false; end if;   -- מפגש שעבר: בלי מייל$r$);
    if d not like '%-- מפגש שעבר: בלי מייל%' then raise exception 'harpatka_pay_mail patch did not apply'; end if;
    execute d;
  end if;
end $do$;
