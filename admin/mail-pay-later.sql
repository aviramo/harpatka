-- תשלום בהמשך: גם הוא מציע לשלוח אישור מקום (כמו "לא לתשלום"), רק אם עוד לא נשלח מייל על המפגש (pay_mail_sent_at)
do $d$ declare f text; begin
  f := pg_get_functiondef('__S__.harpatka_close_payment_mail(uuid, uuid, boolean)'::regprocedure);
  if f like '%later := %' then return; end if;
  f := replace(f, 'nopay boolean;', 'nopay boolean; later boolean;');
  f := replace(f, 'nopay := coalesce(a.no_pay, false);', 'nopay := coalesce(a.no_pay, false); later := a.pay_later_at is not null and not nopay;');
  f := replace(f, 'if not nopay then', 'if not nopay and not later then');
  f := replace(f, 'if nopay then', 'if nopay or later then');
  execute f;
end $d$;
