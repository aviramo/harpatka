-- ==========================================================================
-- אזור אישי למשתתף (me/): כניסה עם גוגל, מחובר לאותו חיבור של לוח השיתופים (harpatka_members).
-- הגישה רק דרך פונקציות (security definer); רק חיבור מאושר עם משתתף מקושר רואה את הנתונים שלו.
-- מנהל (harpatka_admins) יכול להתחזות לכל משתתף: harpatka_me(p_as => <מזהה משתתף>).
-- להריץ פעם אחת (אידמפוטנטי). דורש board.sql, board-claim.sql, finance/payments/price-tiers.
-- ==========================================================================

alter table public.harpatka_members add column if not exists wants_me boolean not null default false;

-- מי שמבקש אזור אישי: אותה בקשת חיבור כמו בלוח (ממתינה לאישור מנהל), עם סימון שביקש אזור אישי
create or replace function public.harpatka_me_claim(p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare r text;
begin
  r := public.harpatka_board_claim(p_phone);
  update public.harpatka_members set wants_me = true where user_id = auth.uid();
  if r = 'pending' then perform public.harpatka_notify_member(auth.uid()); end if;
  return r;
end $$;
revoke all on function public.harpatka_me_claim(text) from public;
grant execute on function public.harpatka_me_claim(text) to authenticated;

-- כל מה שהמשתתף רואה (ומה שמנהל רואה בהתחזות)
create or replace function public.harpatka_me(p_as uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  adm boolean := public.harpatka_is_admin();
  m public.harpatka_members;
  pid uuid;
  pa public.harpatka_participants;
  imp boolean := false;
  bal numeric := 0;
  nxt public.harpatka_meetings;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  meetings jsonb;
  nxt_json jsonb := null;
  price numeric;
begin
  if uid is null then raise exception 'auth'; end if;
  if p_as is not null then
    if not adm then raise exception 'forbidden'; end if;
    pid := p_as; imp := true;
  else
    select * into m from public.harpatka_members where user_id = uid;
    if not found then return jsonb_build_object('status', 'none', 'admin', adm); end if;
    if m.status = 'blocked' or m.status = 'removed' then return jsonb_build_object('status', 'blocked', 'admin', adm); end if;
    if m.status <> 'approved' or m.participant_id is null then
      return jsonb_build_object('status', case when m.participant_id is null then 'none' else 'pending' end, 'admin', adm);
    end if;
    pid := m.participant_id;
  end if;
  select * into pa from public.harpatka_participants where id = pid and active;
  if not found then return jsonb_build_object('status', 'none', 'admin', adm); end if;

  select coalesce(sum(case when kind in ('credit', 'deposit') then amount
                           when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0)
    into bal from public.harpatka_payments where participant_id = pid;

  select coalesce(jsonb_agg(x order by (x->>'date') desc), '[]'::jsonb) into meetings from (
    select jsonb_build_object(
      'id', mt.id, 'date', mt.meeting_date, 'time', to_char(mt.meeting_time, 'HH24:MI'),
      'attended', coalesce(a.attended, false), 'free', coalesce(a.no_pay, false),
      'paid', coalesce((select sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end)
                         from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = mt.id), 0),
      'future', mt.meeting_date >= today) as x
    from public.harpatka_attendance a join public.harpatka_meetings mt on mt.id = a.meeting_id
    where a.participant_id = pid
  ) s;

  select * into nxt from public.harpatka_meetings where meeting_date >= today order by meeting_date, meeting_time limit 1;
  if found then
    select t.price into price from public.harpatka_price_tiers t where t.days <= (nxt.meeting_date - today) order by t.days desc limit 1;
    nxt_json := jsonb_build_object('id', nxt.id, 'date', nxt.meeting_date, 'time', to_char(nxt.meeting_time, 'HH24:MI'), 'price', price,
      'registered', exists (select 1 from public.harpatka_attendance where participant_id = pid and meeting_id = nxt.id));
  end if;

  return jsonb_build_object('status', 'ok', 'admin', adm, 'impersonating', imp,
    'participant', jsonb_build_object('id', pa.id, 'first_name', pa.first_name, 'last_name', pa.last_name, 'phone', pa.phone,
      'age', case when pa.age is null then null else pa.age + (extract(year from age(today, pa.age_set_at)))::int end, 'gender', pa.gender),
    'balance', bal, 'meetings', meetings, 'next', nxt_json);
end $$;
revoke all on function public.harpatka_me(uuid) from public;
grant execute on function public.harpatka_me(uuid) to authenticated;

-- הרשמה למפגש הקרוב (או למפגש עתידי אחר) בלחיצה
drop function if exists public.harpatka_me_register(uuid);
create or replace function public.harpatka_me_register(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare m public.harpatka_members; pid uuid; mt public.harpatka_meetings; today date := (now() at time zone 'Asia/Jerusalem')::date;
begin
  if p_as is not null then
    if not public.harpatka_is_admin() then raise exception 'forbidden'; end if;   -- מנהל פועל במקום המשתתף (התחזות)
    pid := p_as;
  else
    select * into m from public.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  select * into mt from public.harpatka_meetings where id = p_meeting;
  if not found or mt.meeting_date < today then return 'past'; end if;
  if exists (select 1 from public.harpatka_attendance where participant_id = pid and meeting_id = p_meeting) then return 'exists'; end if;
  insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, p_meeting, false);
  return 'registered';
end $$;
revoke all on function public.harpatka_me_register(uuid, uuid) from public;
grant execute on function public.harpatka_me_register(uuid, uuid) to authenticated;

-- עריכת פרטים אישיים (שם, גיל, מגדר, טלפון). שינוי טלפון מעדכן גם את הקישור לחשבון
drop function if exists public.harpatka_me_update(text, text, int, text, text);
create or replace function public.harpatka_me_update(p_first text, p_last text, p_age int, p_gender text, p_phone text, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare m public.harpatka_members; norm text := public.harpatka_normalize_phone(p_phone); target uuid;
begin
  if p_as is not null then
    if not public.harpatka_is_admin() then raise exception 'forbidden'; end if;   -- מנהל פועל במקום המשתתף (התחזות)
    target := p_as;
  else
    select * into m from public.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    target := m.participant_id;
  end if;
  if length(trim(coalesce(p_first, ''))) < 2 or length(trim(coalesce(p_last, ''))) < 2 then return 'invalid_name'; end if;
  if p_age is not null and (p_age < 18 or p_age > 99) then return 'invalid_age'; end if;
  if norm = '' then return 'invalid_phone'; end if;
  if exists (select 1 from public.harpatka_participants where phone_norm = norm and id <> target and active) then return 'phone_taken'; end if;
  update public.harpatka_participants set first_name = trim(p_first), last_name = trim(p_last), age = p_age, age_set_at = current_date,
    gender = case when p_gender in ('male', 'female') then p_gender else null end, phone = trim(p_phone), phone_norm = norm
  where id = target;
  update public.harpatka_members set phone_norm = norm where participant_id = target and p_as is null and user_id = auth.uid();
  return 'ok';
end $$;
revoke all on function public.harpatka_me_update(text, text, int, text, text, uuid) from public;
grant execute on function public.harpatka_me_update(text, text, int, text, text, uuid) to authenticated;

-- הרשמה לאתר מהאזור האישי, בלי שיוך למפגש: כשהטלפון לא נמצא בין המשתתפים נוצר משתתף חדש ומחובר לחשבון (מאושר מיד, כי המשתתף נוצר על ידו ורואה רק את עצמו)
create or replace function public.harpatka_me_signup(p_first text, p_last text, p_age int, p_gender text, p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  pid uuid; was_active boolean;
  m public.harpatka_members;
begin
  if uid is null then raise exception 'auth'; end if;
  if length(trim(coalesce(p_first, ''))) < 2 or length(trim(coalesce(p_last, ''))) < 2 then return 'invalid_name'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id, active into pid, was_active from public.harpatka_participants where phone_norm = norm order by active desc, created_at limit 1;
  if pid is not null then return 'exists'; end if;   -- טלפון שכבר קיים (גם של לא פעיל) לא נפתח מחדש כאן: הוא מחובר רק באישור מנהל (harpatka_me_claim)
  begin
    insert into public.harpatka_participants (first_name, last_name, phone, phone_norm, source, age, age_set_at, gender)
    values (trim(p_first), trim(p_last), trim(p_phone), norm, 'site', p_age, current_date, case when p_gender in ('male', 'female') then p_gender else null end)
    returning id into pid;
  end;
  select * into m from public.harpatka_members where user_id = uid;
  if found then
    if m.status in ('blocked') then return 'blocked'; end if;
    update public.harpatka_members set participant_id = pid, phone_norm = norm, status = 'approved', wants_me = true where user_id = uid;
  else
    insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status, wants_me)
    values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid, 'approved', true);
  end if;
  return 'ok';
end $$;
revoke all on function public.harpatka_me_signup(text, text, int, text, text) from public;
grant execute on function public.harpatka_me_signup(text, text, int, text, text) to authenticated;
