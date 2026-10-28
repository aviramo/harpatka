-- דיווח תשלום גם מפופאפ ההרשמה בדף הבית (28.10.26): מי שנרשם עכשיו (משתתף חדש עם אסימון חיבור, claim_token) יכול לדווח "שילמתי" בלי להתחבר,
-- ומי שמחובר דרך harpatka_me_report_payment. הלוגיקה בפונקציית ליבה אחת (harpatka_report_payment_core). אידמפוטנטי; להריץ על public ואז admin/test-site.sql.

-- סכום הדיווח: המחיר למפגש ברגע הדיווח (לפי מדרגות המחיר של המפגש), נשמר ב-pay_reported_amount ומוצג בדף הניהול
alter table public.harpatka_attendance add column if not exists pay_reported_amount numeric;
alter table test.harpatka_attendance add column if not exists pay_reported_amount numeric;

create or replace function public.harpatka_report_payment_core(pid uuid, p_meeting uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  mt public.harpatka_meetings; a public.harpatka_attendance; pa public.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date; paid numeric; amt numeric;
begin
  select * into mt from public.harpatka_meetings where id = p_meeting;
  if not found or mt.meeting_date < today then return 'past'; end if;
  select * into a from public.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return 'not_registered'; end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  if paid > 0 or coalesce(a.no_pay, false) then return 'already'; end if;
  if a.pay_reported_at is not null then return 'reported'; end if;
  amt := public.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today);
  update public.harpatka_attendance set pay_reported_at = now(), pay_reported_amount = amt where participant_id = pid and meeting_id = p_meeting;
  select * into pa from public.harpatka_participants where id = pid;
  begin
    perform public.harpatka_sys_note(pid, 'דווח על תשלום' || coalesce(' ₪' || amt::text, '') || ' למפגש ' || public.harpatka_meeting_short(p_meeting) || ' (ממתין לאימות)', 'payment_reported', p_meeting);
  exception when others then null;
  end;
  begin
    perform public.harpatka_send_mail('payment_reported',
      jsonb_build_object('name', coalesce(pa.name, ''), 'meeting', to_char(mt.meeting_date, 'DD.MM.YYYY') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || coalesce(' · ' || nullif(mt.city, ''), ''),
        'price', coalesce('₪' || public.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today)::text, ''),
        'admin_link', 'https://harpatka.co.il/admin/?m=' || p_meeting || '&p=' || pid), null, null);
  exception when others then null;   -- כשל במייל לא מבטל את הדיווח
  end;
  return 'ok';
end $$;
revoke all on function public.harpatka_report_payment_core(uuid, uuid) from public, anon, authenticated;

create or replace function public.harpatka_me_report_payment(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare m public.harpatka_members; pid uuid;
begin
  if p_as is not null then
    if not public.harpatka_is_admin() then raise exception 'forbidden'; end if;
    pid := p_as;
  else
    select * into m from public.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  return public.harpatka_report_payment_core(pid, p_meeting);
end $$;
revoke all on function public.harpatka_me_report_payment(uuid, uuid) from public;
grant execute on function public.harpatka_me_report_payment(uuid, uuid) to authenticated;

-- בלי התחברות: האסימון שנוצר בדפדפן בהרשמה (תקף יומיים, קיים רק למשתתף שנוצר מאותה הרשמה)
create or replace function public.harpatka_report_payment_token(p_token uuid, p_meeting uuid)
returns text language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  if p_token is null then return 'invalid'; end if;
  select id into pid from public.harpatka_participants where claim_token = p_token and claim_token_at > now() - interval '2 days' and active limit 1;
  if pid is null then return 'invalid'; end if;
  return public.harpatka_report_payment_core(pid, p_meeting);
end $$;
revoke all on function public.harpatka_report_payment_token(uuid, uuid) from public;
grant execute on function public.harpatka_report_payment_token(uuid, uuid) to anon, authenticated;

-- השלמת סכום לדיווחים שנעשו לפני שהסכום נשמר: המחיר לפי הימים שנותרו ברגע הדיווח
update public.harpatka_attendance a set pay_reported_amount = public.harpatka_meeting_price(m.price_tiers, m.meeting_date - (a.pay_reported_at at time zone 'Asia/Jerusalem')::date)
  from public.harpatka_meetings m where m.id = a.meeting_id and a.pay_reported_at is not null and a.pay_reported_amount is null;
update test.harpatka_attendance a set pay_reported_amount = public.harpatka_meeting_price(m.price_tiers, m.meeting_date - (a.pay_reported_at at time zone 'Asia/Jerusalem')::date)
  from test.harpatka_meetings m where m.id = a.meeting_id and a.pay_reported_at is not null and a.pay_reported_amount is null;
