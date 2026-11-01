-- תשלום מהקרדיט (1.11.26): משתתף יכול לשלם על מפגש מהקרדיט שלו, עד המקסימום שלו. כפתור אחד בכל שלב: קודם הקרדיט, ורק אחר כך פייבוקס.
-- אם מחיר המפגש גבוה מהקרדיט: הקרדיט כולו מנוצל (הקצאה למפגש), השארית נשמרת ב-pay_due_amount, והמשתתף משלם אותה בפייבוקס (ומדווח, ממתין לאימות שלנו).
-- 1) harpatka_attendance.pay_due_amount: מה שנשאר לשלם אחרי ניצול חלקי של הקרדיט (ריק = אין שארית). רישום תשלום למפגש מנקה אותו.
-- 2) harpatka_me מחזירה לכל מפגש גם reported_amount (הסכום שדווח) ו-due (השארית לתשלום).
-- 3) harpatka_report_payment_core: כשיש שארית (pay_due_amount) מדווחים עליה גם כשכבר הוקצה למפגש סכום.
-- 4) harpatka_me_pay_credit(p_meeting, p_as): מקצה למפגש min(קרדיט, מחיר) כהקצאה מהקרדיט (kind = payment, from_credit = true) ושומרת את השארית.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public ו-__ADM__ בפונקציית בדיקת המנהל (test: harpatka_is_admin_site, public: harpatka_is_admin):
--   sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin_site/g' admin/me-pay-credit.sql | supabase db query --linked
--   sed 's/__S__/public/g; s/__ADM__/harpatka_is_admin/g' admin/me-pay-credit.sql | supabase db query --linked
alter table __S__.harpatka_attendance add column if not exists pay_due_amount numeric;

do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me';
  if d is null then raise exception 'harpatka_me not found'; end if;
  if d not like '%''reported_amount''%' then
    d := replace(d, '''reported'', a.pay_reported_at is not null,', '''reported'', a.pay_reported_at is not null, ''reported_amount'', a.pay_reported_amount,');
    if d not like '%''reported_amount''%' then raise exception 'harpatka_me patch (reported_amount) did not apply'; end if;
  end if;
  if d not like '%''due'', a.pay_due_amount%' then
    d := replace(d, '''reported'', a.pay_reported_at is not null,', '''reported'', a.pay_reported_at is not null, ''due'', a.pay_due_amount,');
    if d not like '%''due'', a.pay_due_amount%' then raise exception 'harpatka_me patch (due) did not apply'; end if;
  end if;
  execute d;
end $$;

-- רישום תשלום למפגש מנקה גם דיווח וגם שארית שנשארה לתשלום
create or replace function __S__.harpatka_clear_pay_reported() returns trigger
language plpgsql security definer set search_path = __S__, public as $function$
begin
  if new.meeting_id is not null and new.kind = 'payment' then
    update __S__.harpatka_attendance set pay_reported_at = null, pay_rejected_at = null, pay_due_amount = null
      where participant_id = new.participant_id and meeting_id = new.meeting_id and (pay_reported_at is not null or pay_rejected_at is not null or pay_due_amount is not null);
  end if;
  return new;
end $function$;

drop function if exists __S__.harpatka_report_payment_core(uuid, uuid, numeric);
create or replace function __S__.harpatka_report_payment_core(pid uuid, p_meeting uuid)
returns text language plpgsql security definer set search_path = __S__, public as $function$
declare
  mt __S__.harpatka_meetings; a __S__.harpatka_attendance; pa __S__.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date; paid numeric; amt numeric; due numeric;
begin
  select * into mt from __S__.harpatka_meetings where id = p_meeting;
  if not found then return 'past'; end if;
  select * into a from __S__.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return 'not_registered'; end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from __S__.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  due := nullif(a.pay_due_amount, 0);   -- שארית אחרי ניצול חלקי של הקרדיט: מדווחים עליה גם כשכבר הוקצה למפגש סכום
  if coalesce(a.no_pay, false) or (paid > 0 and due is null) then return 'already'; end if;
  if a.pay_reported_at is not null then return 'reported'; end if;
  amt := coalesce(due, __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0)));
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

revoke all on function __S__.harpatka_report_payment_core(uuid, uuid) from public, anon, authenticated;   -- פנימית: נקראת רק מהפונקציות שמעליה
drop function if exists __S__.harpatka_me_pay_credit(uuid, uuid, boolean);
create or replace function __S__.harpatka_me_pay_credit(p_meeting uuid, p_as uuid default null)
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
  -- שארית אחרי ניצול חלקי: נשמרת (אחרי הטריגר שמנקה אותה ברישום תשלום), והמשתתף משלם אותה בפייבוקס
  if rem > 0 then update __S__.harpatka_attendance set pay_due_amount = rem where participant_id = pid and meeting_id = p_meeting; end if;
  return jsonb_build_object('status', 'ok', 'allocated', amt, 'remaining', rem, 'credit_left', bal - amt);
end $function$;
revoke all on function __S__.harpatka_me_pay_credit(uuid, uuid) from public;
grant execute on function __S__.harpatka_me_pay_credit(uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
