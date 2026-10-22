alter table public.harpatka_participants add column if not exists active boolean not null default true;
-- משתתף "נמחק" = active=false (בלי מחיקה בפועל): מוסתר מדף הניהול; הטלפון הוא המפתח וחוזר להיות פעיל בהרשמה חדשה; השם הפרטי נשאר בשיתופים
create or replace function public.harpatka_signup(p_phone text, p_age int default null, p_gender text default null, p_src text default null, p_first text default null, p_last text default null, p_name text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  fullname text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  fn  text; ln text; nm text;
  pid uuid; mid uuid; md date; mt time; act boolean;
  res text := 'created';
begin
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
    else update public.harpatka_participants set active = true where id = pid; res := 'created'; end if;
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
  end if;

  if res = 'created' then
    perform public.harpatka_notify_signup(nm, n, p_age, md, mt, pid, mid, p_gender);
  end if;
  return res;
end $$;
create or replace function public.harpatka_board_claim(p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  m public.harpatka_members;
  pid uuid;
  adm boolean := public.harpatka_is_admin();
  had boolean;
  mail_on text;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  had := found;
  if had and (m.participant_id is not null or m.status = 'approved') then return m.status; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id into pid from public.harpatka_participants where phone_norm = norm and active order by created_at limit 1;
  if pid is null and not adm then return 'not_registered'; end if;
  if had then
    update public.harpatka_members set participant_id = pid, phone_norm = norm where user_id = uid;
    perform public.harpatka_notify_member(uid);
    return m.status;
  end if;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status)
  values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid,
          case when adm then 'approved' else 'pending' end);
  if not adm then perform public.harpatka_notify_member(uid); end if;
  return case when adm then 'approved' else 'pending' end;
end $$;
create or replace function public.harpatka_board_profile()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', m.status, 'can_share', m.participant_id is not null,
    'can_post', public.harpatka_is_admin() or exists (select 1 from public.harpatka_attendance at join public.harpatka_participants pp on pp.id = at.participant_id where at.participant_id = m.participant_id and pp.active),
    'name', coalesce(pa.name, nullif(m.google_name, ''), m.email),
    'first_name', coalesce(nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), ''))
  from public.harpatka_members m left join public.harpatka_participants pa on pa.id = m.participant_id where m.user_id = auth.uid();
$$;

-- הכותב מסיר/מחזיר את תגית השם הפרטי בפוסט או בתגובה שלו
create or replace function public.harpatka_board_set_name(p_id uuid, p_show boolean)
returns text language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'auth'; end if;
  update public.harpatka_posts set show_name = coalesce(p_show, false) where id = p_id and user_id = auth.uid() and deleted_at is null;
  if not found then return 'none'; end if;
  return 'ok';
end $$;
drop function if exists public.harpatka_board_post(text, uuid);
drop function if exists public.harpatka_board_post(text, uuid, boolean);
create or replace function public.harpatka_board_post(p_body text, p_parent uuid default null, p_share boolean default false, p_show_name boolean default true)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m public.harpatka_members;
  body text := btrim(coalesce(p_body, ''));
  par public.harpatka_posts;
  pm public.harpatka_members;
  new_id uuid := gen_random_uuid();
  adm boolean := public.harpatka_is_admin();
  pa public.harpatka_participants;
  mail_on text;
  share boolean;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if not found then return 'no_member'; end if;
  if m.status = 'blocked' then return 'blocked'; end if;
  if not adm and not exists (select 1 from public.harpatka_attendance at join public.harpatka_participants pp on pp.id = at.participant_id where at.participant_id = m.participant_id and pp.active) then return 'no_meeting'; end if;   -- רק מי שרשום לפחות למפגש אחד
  if body = '' then return 'empty'; end if;
  if length(body) > 2000 then return 'long'; end if;
  if not adm and (select count(*) from public.harpatka_posts where user_id = uid and deleted_at is null and approved_at is null) >= 5 then return 'limit'; end if;
  if p_parent is not null then
    select * into par from public.harpatka_posts where id = p_parent and deleted_at is null;
    if not found then return 'no_parent'; end if;
    select * into pm from public.harpatka_members where user_id = par.user_id;
    if (pm.status <> 'approved' or par.approved_at is null) and par.user_id <> uid then return 'no_parent'; end if;
  end if;
  share := coalesce(p_share, false) and p_parent is not null and m.participant_id is not null;
  insert into public.harpatka_posts (id, parent_id, root_id, user_id, body, approved_at, share_phone, show_name)
  values (new_id, p_parent, coalesce(par.root_id, new_id), uid, body, case when adm or m.status = 'approved' then now() end, share, coalesce(p_show_name, true));   -- משתמש מקושר מתפרסם מיד
  if adm then return 'ok'; end if;
  select value into mail_on from public.harpatka_settings where key = 'mail_v2';
  if mail_on = '1' then begin
    select * into pa from public.harpatka_participants where id = m.participant_id;
    perform public.harpatka_send_mail(case when m.status = 'approved' then 'post_published' else 'post_pending' end, jsonb_build_object(
      'kind', case when p_parent is null then 'פוסט' else 'תגובה' end,
      'body_html', replace(public.harpatka_html_esc(body), E'\n', '<br>') || case when share then '<br><br><i>(המגיב/ה בחר/ה לשתף את הטלפון עם בעל/ת הפוסט)</i>' else '' end,
      'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
      'identity', (case when pa.id is not null then 'משתתף/ת במערכת, טלפון ' || coalesce(pa.phone, '') || ' · חשבון גוגל ' || m.email
                       else 'הטלפון שהוזן (' || m.phone_norm || ') לא נמצא בין המשתתפים · חשבון גוגל ' || m.email end)
                  || case when m.status = 'pending' then ' · החיבור של המשתמש/ת עוד לא אושר (נשלח מייל נפרד)' else '' end,
      'admin_link', 'https://harpatka.co.il/board/', 'hide_link', 'https://harpatka.co.il/board/?hide=' || new_id));
  exception when others then null; end; end if;
  return case when m.status = 'approved' then 'ok' else 'pending' end;
end $$;
revoke all on function public.harpatka_board_post(text, uuid, boolean, boolean) from public;
grant execute on function public.harpatka_board_post(text, uuid, boolean, boolean) to authenticated;


notify pgrst, 'reload schema';
