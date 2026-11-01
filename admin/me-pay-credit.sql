-- תשלום מהקרדיט (1.11.26): משתתף יכול לשלם על מפגש מהקרדיט שלו, עד המקסימום שלו.
-- אם מחיר המפגש גבוה מהקרדיט, הקרדיט כולו מנוצל והשארית משולמת בפייבוקס (ומדווחת, ממתינה לאימות שלנו).
-- 1) harpatka_me מחזירה לכל מפגש גם reported_amount (הסכום שדווח: שארית אחרי ניצול קרדיט).
-- 2) harpatka_report_payment_core מקבלת סכום אופציונלי (p_amount): דיווח על שארית אחרי הקצאה חלקית מהקרדיט, גם כשכבר הוקצה למפגש סכום.
-- 3) harpatka_me_pay_credit(p_meeting, p_as, p_report): מקצה למפגש min(קרדיט, מה שנשאר לשלם) כהקצאה מהקרדיט (kind = payment, from_credit = true), ובבקשה (p_report) מדווחת גם על השארית.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public ו-__ADM__ בפונקציית בדיקת המנהל (test: harpatka_is_admin_site, public: harpatka_is_admin):
--   sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin_site/g' admin/me-pay-credit.sql | supabase db query --linked
--   sed 's/__S__/public/g; s/__ADM__/harpatka_is_admin/g' admin/me-pay-credit.sql | supabase db query --linked
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me';
  if d is null then raise exception 'harpatka_me not found'; end if;
  if d not like '%''reported_amount''%' then
    d := replace(d, '''reported'', a.pay_reported_at is not null,', '''reported'', a.pay_reported_at is not null, ''reported_amount'', a.pay_reported_amount,');
    if d not like '%''reported_amount''%' then raise exception 'harpatka_me patch did not apply'; end if;
    execute d;
  end if;
end $$;

drop function if exists __S__.harpatka_report_payment_core(uuid, uuid);
create or replace function __S__.harpatka_report_payment_core(pid uuid, p_meeting uuid, p_amount numeric default null)
returns text language plpgsql security definer set search_path = __S__, public as $function$
declare
  mt __S__.harpatka_meetings; a __S__.harpatka_attendance; pa __S__.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date; paid numeric; amt numeric;
begin
  select * into mt from __S__.harpatka_meetings where id = p_meeting;
  if not found then return 'past'; end if;
  select * into a from __S__.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return 'not_registered'; end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from __S__.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  -- בלי p_amount (דיווח רגיל): כבר שולם / חינם / כבר דווח. עם p_amount (שארית אחרי ניצול קרדיט): מדווחים גם כשכבר הוקצה למפגש סכום
  if coalesce(a.no_pay, false) or (p_amount is null and paid > 0) then return 'already'; end if;
  if p_amount is null and a.pay_reported_at is not null then return 'reported'; end if;
  amt := coalesce(p_amount, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)));
  update __S__.harpatka_attendance set pay_reported_at = now(), pay_reported_amount = amt, pay_rejected_at = null where participant_id = pid and meeting_id = p_meeting;
  select * into pa from __S__.harpatka_participants where id = pid;
  begin
    perform __S__.harpatka_sys_note(pid, 'דווח על תשלום' || coalesce(' ₪' || amt::text, '') || ' למפגש ' || __S__.harpatka_meeting_short(p_meeting) || ' (ממתין לאימות)', 'payment_reported', p_meeting, null, null, amt);
  exception when others then null;
  end;
  begin
    perform __S__.harpatka_send_mail('payment_reported',
      jsonb_build_object('name', coalesce(pa.name, ''), 'meeting', to_char(mt.meeting_date, 'DD.MM.YYYY') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || coalesce(' · ' || nullif(mt.city, ''), ''),
        'price', coalesce('₪' || amt::text, ''),
        'admin_link', 'https://harpatka.co.il/admin/?m=' || p_meeting || '&p=' || pid), null, null);
  exception when others then null;   -- כשל במייל לא מבטל את הדיווח
  end;
  return 'ok';
end $function$;
revoke all on function __S__.harpatka_report_payment_core(uuid, uuid, numeric) from public, anon, authenticated;

create or replace function __S__.harpatka_me_pay_credit(p_meeting uuid, p_as uuid default null, p_report boolean default false)
returns jsonb language plpgsql security definer set search_path = __S__, public as $function$
declare
  m __S__.harpatka_members; pid uuid; mt __S__.harpatka_meetings; a __S__.harpatka_attendance; pa __S__.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  price numeric; paid numeric; due numeric; bal numeric; amt numeric; rem numeric;
begin
  if p_as is not null then
    if not __S__.__ADM__() then raise exception 'forbidden'; end if;   -- מנהל פועל במקום המשתתף (התחזות)
    pid := p_as;
  else
    select * into m from __S__.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  select * into mt from __S__.harpatka_meetings where id = p_meeting;
  if not found then return jsonb_build_object('status', 'missing'); end if;
  select * into a from __S__.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return jsonb_build_object('status', 'not_registered'); end if;
  if coalesce(a.no_pay, false) then return jsonb_build_object('status', 'free'); end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from __S__.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  if paid > 0 then return jsonb_build_object('status', 'already'); end if;
  price := __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0));
  due := greatest(coalesce(price, 0), 0);
  if due <= 0 then return jsonb_build_object('status', 'already'); end if;
  -- הקרדיט: הפקדות וזיכויים פחות הקצאות והחזרים מהקרדיט (אותו חישוב כמו harpatka_me)
  select coalesce(sum(case when kind in ('credit', 'deposit') then amount when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0)
    into bal from __S__.harpatka_payments where participant_id = pid;
  if bal <= 0 then return jsonb_build_object('status', 'no_credit'); end if;
  amt := least(bal, due);
  select * into pa from __S__.harpatka_participants where id = pid;
  insert into __S__.harpatka_payments (participant_id, meeting_id, kind, amount, from_credit, author_name)
    values (pid, p_meeting, 'payment', amt, true, coalesce(nullif(pa.name, ''), 'משתתף'));
  rem := due - amt;
  if rem > 0 and p_report then perform __S__.harpatka_report_payment_core(pid, p_meeting, rem); end if;   -- שארית: מדווחת (פייבוקס), ממתינה לאימות
  return jsonb_build_object('status', 'ok', 'allocated', amt, 'remaining', rem, 'credit_left', bal - amt);
end $function$;
revoke all on function __S__.harpatka_me_pay_credit(uuid, uuid, boolean) from public;
grant execute on function __S__.harpatka_me_pay_credit(uuid, uuid, boolean) to authenticated;
notify pgrst, 'reload schema';
