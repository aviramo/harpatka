-- הערות מערכת אוטומטיות על כל שינוי בסטטוס ועל כל הרשמה/שיוך של משתתף (מעכשיו). מי ביצע (מנהל) מצוין בסוף ההערה.
alter table public.harpatka_notes add column if not exists system boolean not null default false;
-- יומן אירועים מובנה (בנוסף לטקסט) כדי שאפשר יהיה לסנן/לצבוע לפי סוג אירוע וסטטוס:
-- event_type: registered | reregistered | reactivated | meeting_linked | walk_in | status_changed | attended | attendance_cancelled | meeting_removed | deactivated
-- old_status/new_status: unpaid | requested | paid | exempt
alter table public.harpatka_notes add column if not exists event_type text;
alter table public.harpatka_notes add column if not exists meeting_id uuid;
alter table public.harpatka_notes add column if not exists old_status text;
alter table public.harpatka_notes add column if not exists new_status text;
alter table public.harpatka_notes add column if not exists amount numeric;
alter table public.harpatka_notes add column if not exists source text;
create index if not exists harpatka_notes_event on public.harpatka_notes (event_type, new_status);

create or replace function public.harpatka_meeting_label(p_mid uuid)
returns text language sql stable security definer set search_path = public as $$
  select 'יום ' || (array['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת'])[extract(dow from m.meeting_date)::int + 1] || ' '
    || ltrim(to_char(m.meeting_date, 'DD'), '0') || '.' || ltrim(to_char(m.meeting_date, 'MM'), '0') || ' · ' || to_char(m.meeting_time, 'HH24:MI')
  from public.harpatka_meetings m where m.id = p_mid;
$$;
create or replace function public.harpatka_meeting_short(p_mid uuid)
returns text language sql stable security definer set search_path = public as $$
  select ltrim(to_char(m.meeting_date, 'DD'), '0') || '.' || ltrim(to_char(m.meeting_date, 'MM'), '0') from public.harpatka_meetings m where m.id = p_mid;
$$;

drop function if exists public.harpatka_sys_note(uuid, text);
create or replace function public.harpatka_sys_note(p_pid uuid, p_body text, p_event text default null, p_meeting uuid default null, p_old text default null, p_new text default null, p_amount numeric default null, p_source text default null)
returns void language plpgsql security definer set search_path = public as $$
declare actor text := coalesce(nullif(auth.jwt() -> 'user_metadata' ->> 'full_name', ''), auth.jwt() ->> 'email');
begin
  -- כותב ההערה הוא מי שביצע את השינוי (מנהל); בהרשמה מהאתר, בלי מנהל: "מערכת". הטקסט בלי "בוצע על ידי".
  insert into public.harpatka_notes (participant_id, body, author_email, author_name, system, event_type, meeting_id, old_status, new_status, amount, source)
  values (p_pid, p_body, coalesce(auth.jwt() ->> 'email', 'system'), coalesce(actor, 'מערכת'), true, p_event, p_meeting, p_old, p_new, p_amount, p_source);
exception when others then null;
end $$;
revoke all on function public.harpatka_sys_note(uuid, text, text, uuid, text, text, numeric, text) from public, anon, authenticated;

create or replace function public.harpatka_pay_code(p_paid boolean, p_exempt boolean, p_req timestamptz)
returns text language sql immutable as $$
  select case when coalesce(p_exempt, false) then 'exempt' when coalesce(p_paid, false) then 'paid' when p_req is not null then 'requested' else 'unpaid' end;
$$;

create or replace function public.harpatka_pay_status(p_paid boolean, p_exempt boolean, p_req timestamptz)
returns text language sql immutable as $$
  select case when coalesce(p_exempt, false) then 'חינם' when coalesce(p_paid, false) then 'שילם' when p_req is not null then 'בטיפול' else 'טרם טופל' end;
$$;

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
        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end || ' (היה: ' || os || ')',
        'status_changed', new.meeting_id, public.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at), public.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at), case when ns = 'שילם' then new.paid_amount end);
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
revoke all on function public.harpatka_att_notes() from public, anon, authenticated;
drop trigger if exists harpatka_att_notes on public.harpatka_attendance;
create trigger harpatka_att_notes after insert or update of paid, exempt, pay_requested_at, attended or delete on public.harpatka_attendance
  for each row execute function public.harpatka_att_notes();

create or replace function public.harpatka_part_notes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('harpatka.skip_note', true) = '1' then return new; end if;
  if tg_op = 'INSERT' then
    perform public.harpatka_sys_note(new.id, 'נרשם/ה ' || case new.source when 'site-ad' then 'דרך האתר (ממומן)' when 'site' then 'דרך האתר' else '(נוסף/ה ידנית)' end, 'registered', null, null, null, null, coalesce(nullif(new.source, ''), 'manual'));
  elsif tg_op = 'UPDATE' and new.active is distinct from old.active then
    perform public.harpatka_sys_note(new.id, case when new.active then 'חזר/ה להיות פעיל/ה' else 'הוסר/ה (לא פעיל/ה)' end, case when new.active then 'reactivated' else 'deactivated' end);
  end if;
  return new;
exception when others then return new;
end $$;
revoke all on function public.harpatka_part_notes() from public, anon, authenticated;
drop trigger if exists harpatka_part_notes on public.harpatka_participants;
create trigger harpatka_part_notes after insert or update of active on public.harpatka_participants
  for each row execute function public.harpatka_part_notes();

-- הרשמה מהאתר: הערה אחת (הרשמה + שיוך למפגש)
drop function if exists public.harpatka_signup(text, int, text, text, text, text, text);
create or replace function public.harpatka_signup(p_phone text, p_age int default null, p_gender text default null, p_src text default null, p_first text default null, p_last text default null, p_name text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  fullname text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  fn  text; ln text; nm text;
  pid uuid; mid uuid; md date; mt time; act boolean;
  res text := 'created'; linked int := 0; react boolean := false; base text; tail text;
begin
  perform set_config('harpatka.skip_note', '1', true);   -- הרשמה מהטופס = הערת מערכת אחת (נכתבת בסוף), בלי הערות של הטריגרים
  if p_first is not null or p_last is not null then
    fn := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g')); ln := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
  else
    fn := split_part(fullname, ' ', 1); ln := btrim(substr(fullname, length(fn) + 1));
  end if;
  nm := btrim(fn || ' ' || ln);
  if char_length(fn) < 2 or char_length(fn) > 40 or char_length(ln) > 40 or char_length(nm) > 60 then return 'invalid_name'; end if;
  if n = '' then return 'invalid_phone'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is not null and p_gender not in ('male', 'female') then return 'invalid_gender'; end if;

  select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
    where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
    order by meeting_date, meeting_time limit 1;

  select id, active, name into pid, act, nm from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null then
    -- הטלפון הוא המפתח: משתתף קיים לא מתעדכן. משתתף לא פעיל (הוסר) חוזר להיות פעיל, בלי שינוי בשאר השדות
    if act then res := 'exists';
    else update public.harpatka_participants set active = true where id = pid; res := 'created'; react := true; end if;
  else
    begin
      insert into public.harpatka_participants (first_name, last_name, phone, age, age_set_at, source, gender)
        values (fn, ln, n, p_age, current_date, case when p_src = 'p' then 'site-ad' else 'site' end, p_gender)
        returning id into pid;
    exception when unique_violation then
      select id into pid from public.harpatka_participants where phone_norm = n limit 1;
      res := 'exists';
    end;
  end if;

  if mid is not null and pid is not null then
    insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false)
      on conflict (participant_id, meeting_id) do nothing;
    get diagnostics linked = row_count;
  end if;
  if pid is not null then
    base := case when res = 'exists' then 'נרשם/ה שוב דרך האתר' when react then 'חזר/ה להיות פעיל/ה בהרשמה חדשה דרך האתר'
                 else 'נרשם/ה דרך האתר' || case when p_src = 'p' then ' (ממומן)' else '' end end;
    tail := case when mid is null then ' (אין מפגש קרוב)' when linked > 0 then ' ושויך/ה למפגש ' || public.harpatka_meeting_label(mid)
                 else ' (כבר משויך/ת למפגש ' || public.harpatka_meeting_label(mid) || ')' end;
    perform public.harpatka_sys_note(pid, base || tail, case when res = 'exists' then 'reregistered' when react then 'reactivated' else 'registered' end, mid, null, null, null, case when p_src = 'p' then 'site-ad' else 'site' end);
  end if;

  if res = 'created' then
    perform public.harpatka_notify_signup(nm, n, p_age, md, mt, pid, mid, p_gender);
  end if;
  return res;
end $$;
revoke all on function public.harpatka_signup(text, int, text, text, text, text, text) from public;
grant execute on function public.harpatka_signup(text, int, text, text, text, text, text) to anon, authenticated;
notify pgrst, 'reload schema';
