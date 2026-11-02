-- סגירת תשלום בלי שום תשלום (2.11.26): המפגש נסגר כשלא שולם עליו כלום. נשמר כ-no_pay = true (כך כל החישובים, החוב, הסינון והאזור האישי מתנהגים כמו "חינם")
-- ובנוסף pay_closed_at, שמבדיל בתצוגה בדף הניהול בין "נסגר" ל"חינם". בלי מייל למשתתף, כי הוא לא שילם.
-- הערת המערכת נכתבת מדף הניהול (payment_closed, payment_reopened), ולכן הטריגר לא רושם עליה גם "סומן כחינם".
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/pay-closed.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/pay-closed.sql | supabase db query --linked
alter table __S__.harpatka_attendance add column if not exists pay_closed_at timestamptz;
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_att_notes';
  if d not like '%pay_closed_at%' then
    d := replace(d, 'if coalesce(old.no_pay, false) <> coalesce(new.no_pay, false) then', 'if coalesce(old.no_pay, false) <> coalesce(new.no_pay, false) and new.pay_closed_at is null and old.pay_closed_at is null then');
    if d not like '%pay_closed_at%' then raise exception 'harpatka_att_notes patch did not apply'; end if;
    execute d;
  end if;
end $$;
notify pgrst, 'reload schema';
