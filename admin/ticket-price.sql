-- סגירת מחיר בתשלום בהמשך (11.11.26): מחיר הכרטיס של המשתתף למפגש (harpatka_attendance.ticket_price). כשהוא מוגדר הוא המחיר של אותו משתתף במפגש,
-- גם אם מדרגות המחיר עולות אחר כך: בדף הניהול (הסכום המוצע ומה שנשאר לשלם), באזור האישי ובדף הבית (המחיר והכפתור), בדיווח על תשלום, בניצול קרדיט ובמייל ההרשמה.
-- בלי ticket_price המחיר נקבע לפי המדרגות כמו קודם. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/ticket-price.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/ticket-price.sql | supabase db query --linked
alter table __S__.harpatka_attendance add column if not exists ticket_price integer;

do $do$
declare d text; n text;
begin
  -- harpatka_me: מחיר המפגש ברשימת המפגשים של המשתתף
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace x on x.oid = p.pronamespace where x.nspname = '__S__' and p.proname = 'harpatka_me';
  if d is not null and d not like '%a.ticket_price%' then
    n := replace(d, '''price'', __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0))) as x', '''price'', coalesce(a.ticket_price, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)))) as x');
    if n = d then raise exception 'harpatka_me patch did not apply'; end if;
    execute n;
  end if;
  -- ניצול קרדיט של המשתתף עצמו
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace x on x.oid = p.pronamespace where x.nspname = '__S__' and p.proname = 'harpatka_me_pay_credit';
  if d is not null and d not like '%a.ticket_price%' then
    n := replace(d, 'price := __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0));', 'price := coalesce(a.ticket_price, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)));');
    if n = d then raise exception 'harpatka_me_pay_credit patch did not apply'; end if;
    execute n;
  end if;
  -- מייל "נרשמת למפגש, נשאר לשלם"
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace x on x.oid = p.pronamespace where x.nspname = '__S__' and p.proname = 'harpatka_reg_mail_send';
  if d is not null and d not like '%a.ticket_price%' then
    n := replace(d, 'price := __S__.harpatka_meeting_price(mt.price_tiers, lft);', 'price := coalesce(a.ticket_price, __S__.harpatka_meeting_price(mt.price_tiers, lft));');
    if n = d then raise exception 'harpatka_reg_mail_send patch did not apply'; end if;
    execute n;
  end if;
  -- דיווח על תשלום
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace x on x.oid = p.pronamespace where x.nspname = '__S__' and p.proname = 'harpatka_report_payment_core';
  if d is not null and d not like '%a.ticket_price%' then
    n := replace(d, 'amt := coalesce(due, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)));', 'amt := coalesce(due, a.ticket_price, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)));');
    if n = d then raise exception 'harpatka_report_payment_core patch did not apply'; end if;
    execute n;
  end if;
end $do$;
