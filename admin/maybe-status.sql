-- סטטוס תשלום "אולי": דינו כדין "ישלם" (צהוב, בסינון ובסטטיסטיקות כמו חינם). עמודה maybe
alter table public.harpatka_attendance add column if not exists maybe boolean not null default false;

create or replace function public.harpatka_pay_code(p_paid boolean, p_exempt boolean, p_req timestamptz, p_will boolean, p_maybe boolean)
returns text language sql immutable as $$
  select case when coalesce(p_exempt, false) then 'exempt' when coalesce(p_paid, false) then 'paid' when coalesce(p_will, false) then 'willpay' when coalesce(p_maybe, false) then 'maybe' when p_req is not null then 'requested' else 'unpaid' end;
$$;
create or replace function public.harpatka_pay_status(p_paid boolean, p_exempt boolean, p_req timestamptz, p_will boolean, p_maybe boolean)
returns text language sql immutable as $$
  select case when coalesce(p_exempt, false) then 'חינם' when coalesce(p_paid, false) then 'שילם' when coalesce(p_will, false) then 'ישלם' when coalesce(p_maybe, false) then 'אולי' when p_req is not null then 'בטיפול' else 'טרם טופל' end;
$$;

CREATE OR REPLACE FUNCTION public.harpatka_att_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare os text; ns text;
begin
  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if coalesce(new.attended, false) then
      perform public.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);
    else
      perform public.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id);
    end if;
  elsif tg_op = 'UPDATE' then
    os := public.harpatka_pay_status(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe); ns := public.harpatka_pay_status(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe);
    if os <> ns then
      perform public.harpatka_sys_note(new.participant_id, 'סטטוס למפגש ' || public.harpatka_meeting_short(new.meeting_id) || ': ' || ns
        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end
        || case when ns = 'שילם' and new.pay_method is not null then ' ב' || public.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end || ' (היה: ' || os || ')',
        'status_changed', new.meeting_id, public.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe), public.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe), case when ns = 'שילם' then new.paid_amount end, null, case when ns = 'שילם' then new.pay_method end);
    end if;
    if coalesce(old.attended, false) <> coalesce(new.attended, false) then
      perform public.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || public.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);
    end if;
    if (old.details_sent_at is null) <> (new.details_sent_at is null) then
      perform public.harpatka_sys_note(new.participant_id, case when new.details_sent_at is not null then 'נשלחו פרטי הערב (וואטסאפ) למפגש ' else 'סימון שליחת פרטי הערב בוטל למפגש ' end || public.harpatka_meeting_short(new.meeting_id),
        case when new.details_sent_at is not null then 'details_sent' else 'details_unsent' end, new.meeting_id);
    end if;
  elsif tg_op = 'DELETE' then
    perform public.harpatka_sys_note(old.participant_id, 'הוסר/ה מהמפגש ' || public.harpatka_meeting_short(old.meeting_id), 'meeting_removed', old.meeting_id);
  end if;
  return coalesce(new, old);
exception when others then return coalesce(new, old);
end $function$
;

drop trigger if exists harpatka_att_notes on public.harpatka_attendance;
create trigger harpatka_att_notes after insert or update of paid, exempt, pay_requested_at, will_pay, maybe, attended, details_sent_at or delete on public.harpatka_attendance
  for each row execute function public.harpatka_att_notes();
notify pgrst, 'reload schema';
