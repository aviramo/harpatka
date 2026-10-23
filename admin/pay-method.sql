-- אמצעי תשלום: פייבוקס, ביט, מזומן, בנק, אחר (עם פירוט קצר). נשמר בשיוך למפגש וברישום התשלום, ומופיע בהערת המערכת.
alter table public.harpatka_attendance add column if not exists pay_method text;
alter table public.harpatka_attendance add column if not exists pay_method_note text;
alter table public.harpatka_payments add column if not exists method text;
alter table public.harpatka_payments add column if not exists method_note text;
alter table public.harpatka_notes add column if not exists method text;

create or replace function public.harpatka_method_label(p_method text, p_note text)
returns text language sql immutable as $$
  select case p_method when 'paybox' then 'פייבוקס' when 'bit' then 'ביט' when 'cash' then 'מזומן' when 'bank' then 'בנק'
    when 'other' then 'אחר' || coalesce(': ' || nullif(btrim(p_note), ''), '') else coalesce(p_method, '') end;
$$;
drop function if exists public.harpatka_sys_note(uuid, text);
drop function if exists public.harpatka_sys_note(uuid, text, text, uuid, text, text, numeric, text);
create or replace function public.harpatka_sys_note(p_pid uuid, p_body text, p_event text default null, p_meeting uuid default null, p_old text default null, p_new text default null, p_amount numeric default null, p_source text default null, p_method text default null)
returns void language plpgsql security definer set search_path = public as $$
declare actor text := coalesce(nullif(auth.jwt() -> 'user_metadata' ->> 'full_name', ''), auth.jwt() ->> 'email');
begin
  -- כותב ההערה הוא מי שביצע את השינוי (מנהל); בהרשמה מהאתר, בלי מנהל: "מערכת". הטקסט בלי "בוצע על ידי".
  insert into public.harpatka_notes (participant_id, body, author_email, author_name, system, event_type, meeting_id, old_status, new_status, amount, source, method)
  values (p_pid, p_body, coalesce(auth.jwt() ->> 'email', 'system'), coalesce(actor, 'מערכת'), true, p_event, p_meeting, p_old, p_new, p_amount, p_source, p_method);
exception when others then null;
end $$;

revoke all on function public.harpatka_sys_note(uuid, text, text, uuid, text, text, numeric, text, text) from public, anon, authenticated;

create or replace function public.harpatka_att_notes()
returns trigger language plpgsql security definer set search_path = public as $$
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
    os := public.harpatka_pay_status(old.paid, old.exempt, old.pay_requested_at); ns := public.harpatka_pay_status(new.paid, new.exempt, new.pay_requested_at);
    if os <> ns then
      perform public.harpatka_sys_note(new.participant_id, 'סטטוס למפגש ' || public.harpatka_meeting_short(new.meeting_id) || ': ' || ns
        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end
        || case when ns = 'שילם' and new.pay_method is not null then ' ב' || public.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end || ' (היה: ' || os || ')',
        'status_changed', new.meeting_id, public.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at), public.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at), case when ns = 'שילם' then new.paid_amount end, null, case when ns = 'שילם' then new.pay_method end);
    end if;
    if coalesce(old.attended, false) <> coalesce(new.attended, false) then
      perform public.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || public.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);
    end if;
  elsif tg_op = 'DELETE' then
    perform public.harpatka_sys_note(old.participant_id, 'הוסר/ה מהמפגש ' || public.harpatka_meeting_short(old.meeting_id), 'meeting_removed', old.meeting_id);
  end if;
  return coalesce(new, old);
exception when others then return coalesce(new, old);
end $$;
notify pgrst, 'reload schema';
