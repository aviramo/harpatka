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
  -- הטלפון הוא המפתח: חיבור לאזור האישי מאושר מיד (בלי המתנה לאישור מנהל, ובלי מייל אישור)
  if r = 'pending' then
    update public.harpatka_members set status = 'approved' where user_id = auth.uid() and participant_id is not null and status = 'pending';
    r := 'approved';
  end if;
  return r;
end $$;
revoke all on function public.harpatka_me_claim(text) from public;
grant execute on function public.harpatka_me_claim(text) to authenticated;

-- מחיר מפגש לפי המדרגות שלו (price_tiers = {base, steps}) והימים שנותרו: המדרגה שמתחילה הכי קרוב למפגש מבין אלה שכבר התחילו, אחרת המחיר הרגיל
create or replace function public.harpatka_meeting_price(pt0 jsonb, lft int)
returns int language plpgsql stable set search_path = public as $$
declare pt jsonb := coalesce(pt0, '{"base": 80, "steps": [{"days": 3, "price": 100}]}'::jsonb); price int;
begin
  if jsonb_typeof(pt) <> 'object' then return null; end if;
  select (e->>'price')::int into price from jsonb_array_elements(coalesce(pt->'steps', '[]'::jsonb)) e where lft <= (e->>'days')::int order by (e->>'days')::int asc limit 1;
  if price is null then price := (pt->>'base')::int; end if;
  return price;
end $$;
grant execute on function public.harpatka_meeting_price(jsonb, int) to authenticated;

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

  -- כל המפגשים שרלוונטיים למשתתף: כל מפגש עתידי (רשום או לא, עם מחיר לפי המדרגות של אותו מפגש) ומפגשים שעברו שהוא היה רשום אליהם
  select coalesce(jsonb_agg(x order by (x->>'date')), '[]'::jsonb) into meetings from (
    select jsonb_build_object(
      'id', mt.id, 'date', mt.meeting_date, 'time', to_char(mt.meeting_time, 'HH24:MI'), 'directions', mt.directions, 'name', mt.name, 'city', mt.city,
      'registered', a.participant_id is not null,
      'reported', a.pay_reported_at is not null,
      'rejected', a.pay_rejected_at is not null and a.pay_reported_at is null,
      'attended', coalesce(a.attended, false), 'free', coalesce(a.no_pay, false),
      'paid', coalesce((select sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end)
                         from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = mt.id), 0),
      'future', mt.meeting_date >= today,
      'price', case when mt.meeting_date >= today then public.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today) end) as x
    from public.harpatka_meetings mt left join public.harpatka_attendance a on a.meeting_id = mt.id and a.participant_id = pid
    where mt.meeting_date >= today or a.participant_id is not null
  ) s;

  select * into nxt from public.harpatka_meetings where meeting_date >= today order by meeting_date, meeting_time limit 1;
  if found then
    -- מדרגות המחיר של המפגש עצמו (עמודה price_tiers = {base, steps}): המדרגה שמתחילה הכי קרוב למפגש מבין אלה שכבר התחילו, אחרת המחיר הרגיל
    declare lft int := nxt.meeting_date - today; pt jsonb := coalesce(nxt.price_tiers, '{"base": 80, "steps": [{"days": 3, "price": 100}]}'::jsonb);
    begin
      if jsonb_typeof(pt) = 'object' then
        begin
          select (e->>'price')::int into price from jsonb_array_elements(coalesce(pt->'steps', '[]'::jsonb)) e where lft <= (e->>'days')::int order by (e->>'days')::int asc limit 1;
          if price is null then price := (pt->>'base')::int; end if;
        end;
      end if;
    end;
    nxt_json := jsonb_build_object('id', nxt.id, 'date', nxt.meeting_date, 'time', to_char(nxt.meeting_time, 'HH24:MI'), 'directions', nxt.directions, 'price', price,
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
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is null or p_gender not in ('male', 'female') then return 'invalid_gender'; end if;
  if norm = '' then return 'invalid_phone'; end if;
  if exists (select 1 from public.harpatka_participants where phone_norm = norm and id <> target) then return 'phone_taken'; end if;   -- גם משתתף לא פעיל: הטלפון ייחודי במערכת
  begin
    update public.harpatka_participants set first_name = trim(p_first), last_name = trim(p_last), age = p_age, age_set_at = current_date,
      gender = case when p_gender in ('male', 'female') then p_gender else null end, phone = trim(p_phone), phone_norm = norm
    where id = target;
  exception when unique_violation then return 'phone_taken';   -- מירוץ בין שני עדכונים
  end;
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
  if p_gender is null or p_gender not in ('male', 'female') then return 'invalid_gender'; end if;
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

-- ביטול רישום למפגש (שלא עבר): כל עוד לא סומנה הגעה. לא נוגע בתשלומים שנגבו (נשארים ברשומות התשלום והמנהל מטפל בהם בנפרד)
create or replace function public.harpatka_me_unregister(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare m public.harpatka_members; pid uuid; mt public.harpatka_meetings; a public.harpatka_attendance; today date := (now() at time zone 'Asia/Jerusalem')::date;
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
  if coalesce(a.attended, false) then return 'attended'; end if;
  delete from public.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  return 'cancelled';
end $$;
revoke all on function public.harpatka_me_unregister(uuid, uuid) from public;
grant execute on function public.harpatka_me_unregister(uuid, uuid) to authenticated;

-- חיבור לחשבון גוגל בלי טלפון: מי שנרשם עכשיו בטופס (משתתף חדש) קיבל אסימון בדפדפן (harpatka_signup, p_token); בכניסה עם גוגל האסימון מחבר אותו למשתתף שנוצר (מאושר מיד, כי הוא יצר אותו מהמכשיר הזה). תקף יומיים, חד פעמי.
create or replace function public.harpatka_me_claim_token(p_token uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  pid uuid; norm text; m public.harpatka_members;
begin
  if uid is null then raise exception 'auth'; end if;
  if p_token is null then return 'invalid'; end if;
  select id, phone_norm into pid, norm from public.harpatka_participants
    where claim_token = p_token and claim_token_at > now() - interval '2 days' and active limit 1;
  if pid is null then return 'invalid'; end if;
  if exists (select 1 from public.harpatka_members where participant_id = pid and user_id <> uid) then return 'taken'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if found then
    if m.status in ('blocked') then return 'blocked'; end if;
    update public.harpatka_members set participant_id = pid, phone_norm = norm, status = 'approved', wants_me = true where user_id = uid;
  else
    insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status, wants_me)
    values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid, 'approved', true);
  end if;
  update public.harpatka_participants set claim_token = null where id = pid;
  return 'ok';
end $$;
revoke all on function public.harpatka_me_claim_token(uuid) from public;
grant execute on function public.harpatka_me_claim_token(uuid) to authenticated;
