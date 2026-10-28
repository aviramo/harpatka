-- דיווח תשלום הוא מצב של התשלום במפגש (כמו "שולם" ו"חינם"), לא סטטוס מפגש (28.10.26, מחליף את הסטטוס m_reported של payment-report.sql):
-- עמודה harpatka_attendance.pay_reported_at. בדף הניהול: עיגול ה-₪ הצהוב ו"דווח" בסינון התשלום. כשנרשם תשלום למפגש הדיווח מתנקה.
-- אידמפוטנטי; להריץ על public, ואז admin/test-site.sql (מעתיק את הפונקציות ל-test). העמודה והמיגרציה בשתי הסכמות כאן.

alter table public.harpatka_attendance add column if not exists pay_reported_at timestamptz;
alter table test.harpatka_attendance add column if not exists pay_reported_at timestamptz;

-- מי שסומן בסטטוס הישן m_reported עובר למצב החדש, והסטטוס נמחק
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('update %I.harpatka_attendance set pay_reported_at = coalesce(pay_reported_at, now()), status_key = null where status_key = %L', s, 'm_reported');
    execute format('delete from %I.harpatka_statuses where key = %L', s, 'm_reported');
  end loop;
end $$;

-- הדיווח: מסמן את השיוך (לא את הסטטוס), הערת מערכת ומייל למנהלים
create or replace function public.harpatka_me_report_payment(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  m public.harpatka_members; pid uuid; mt public.harpatka_meetings; a public.harpatka_attendance; pa public.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date; paid numeric;
begin
  if p_as is not null then
    if not public.harpatka_is_admin() then raise exception 'forbidden'; end if;
    pid := p_as;
  else
    select * into m from public.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  select * into mt from public.harpatka_meetings where id = p_meeting;
  if not found or mt.meeting_date < today then return 'past'; end if;
  select * into a from public.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return 'not_registered'; end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  if paid > 0 or coalesce(a.no_pay, false) then return 'already'; end if;
  if a.pay_reported_at is not null then return 'reported'; end if;
  update public.harpatka_attendance set pay_reported_at = now() where participant_id = pid and meeting_id = p_meeting;
  select * into pa from public.harpatka_participants where id = pid;
  begin
    perform public.harpatka_sys_note(pid, 'דווח על תשלום למפגש ' || public.harpatka_meeting_short(p_meeting) || ' (ממתין לאימות)', 'payment_reported', p_meeting);
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
revoke all on function public.harpatka_me_report_payment(uuid, uuid) from public;
grant execute on function public.harpatka_me_report_payment(uuid, uuid) to authenticated;

-- תשלום שנרשם למפגש מנקה את "דווח" של אותו שיוך
create or replace function public.harpatka_clear_pay_reported() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.meeting_id is not null and new.kind = 'payment' then
    update public.harpatka_attendance set pay_reported_at = null where participant_id = new.participant_id and meeting_id = new.meeting_id and pay_reported_at is not null;
  end if;
  return new;
end $$;
drop trigger if exists harpatka_clear_pay_reported on public.harpatka_payments;
create trigger harpatka_clear_pay_reported after insert on public.harpatka_payments for each row execute function public.harpatka_clear_pay_reported();
