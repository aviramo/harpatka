-- מייל על תשלום רק כשהכרטיס שולם במלואו או שהתשלום נסגר (2.11.26). תשלום חלקי, גם מהקרדיט, לא שולח מייל. התבנית payment_partial נשארה בטבלה בלי שימוש. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/pay-mail-full-only.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/pay-mail-full-only.sql | supabase db query --linked
do $do$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_pay_mail_fn';
  if d like '%, true, a.pay_due_amount%' then
    d := regexp_replace(d, $r$if coalesce\(new\.reason, ''\) like 'partial_due:%' then[^\n]*\s+if coalesce\(a\.pay_due_amount, 0\) > 0 then perform [^\n]*\s+return null;\s+end if;$r$, $r$if coalesce(new.reason, '') like 'partial_due:%' then return null; end if;   -- תשלום חלקי: בלי מייל$r$);
    if d like '%, true, a.pay_due_amount%' then raise exception 'harpatka_pay_mail_fn patch did not apply'; end if;
    execute d;
  end if;
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me_pay_credit';
  if d like '%p_meeting, true, rem%' then
    d := regexp_replace(d, $r$if rem > 0 then perform \S+harpatka_pay_mail\(pid, p_meeting, true, rem\);\s+elsif $r$, 'if rem <= 0 and ');
    if d like '%p_meeting, true, rem%' then raise exception 'harpatka_me_pay_credit patch did not apply'; end if;
    execute d;
  end if;
end $do$;

-- נוסח מייל "התשלום התקבל": בלי כותרת שחוזרת על הטקסט, החתימה בשורה אחת, ושני השמות לוואטסאפ לא נשברים בין שורות
update __S__.harpatka_mail_templates set html = replace(replace(replace(html,
    $t$<div style="font-size:24px;font-weight:bold;color:#2C231D;margin-top:8px;line-height:1.3">התשלום התקבל</div>$t$, ''),
    $t$נתראה,<br>אופיר והדר$t$, $t$נתראה, אופיר והדר$t$),
    $t$<a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></div>$t$, $t$<span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>$t$)
  where key = 'payment_confirmed' and (html like '%נתראה,<br>אופיר והדר%' or html like '%margin-top:8px;line-height:1.3%');
