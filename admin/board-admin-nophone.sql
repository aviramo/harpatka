-- מנהל מפרסם/מסמן לב בלי להזין טלפון: נוצר לו חיבור מאושר אוטומטית (בלי משתתף מקושר)
create or replace function public.harpatka_ensure_admin_member()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.harpatka_is_admin() then return; end if;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, status)
  values (auth.uid(), lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), '', 'approved')
  on conflict (user_id) do nothing;
end $$;
revoke all on function public.harpatka_ensure_admin_member() from public, anon;
grant execute on function public.harpatka_ensure_admin_member() to authenticated;

create or replace function public.harpatka_board_like(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m public.harpatka_members;
begin
  if uid is null then raise exception 'auth'; end if;
  perform public.harpatka_ensure_admin_member();
  select * into m from public.harpatka_members where user_id = uid;
  if not found or m.status in ('blocked', 'removed') then return false; end if;
  if exists (select 1 from public.harpatka_likes where post_id = p_id and user_id = uid) then
    delete from public.harpatka_likes where post_id = p_id and user_id = uid; return false;
  end if;
  insert into public.harpatka_likes (post_id, user_id) values (p_id, uid);
  return true;
end $$;

create or replace function public.harpatka_board_profile()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(
    (select jsonb_build_object('status', m.status, 'can_share', m.participant_id is not null,
      'can_post', public.harpatka_is_admin() or exists (select 1 from public.harpatka_attendance at join public.harpatka_participants pp on pp.id = at.participant_id where at.participant_id = m.participant_id and pp.active),
      'name', coalesce(pa.name, nullif(m.google_name, ''), m.email),
      'is_admin', public.harpatka_is_admin(),
      'first_name', coalesce(nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), ''))
     from public.harpatka_members m left join public.harpatka_participants pa on pa.id = m.participant_id where m.user_id = auth.uid()),
    case when auth.uid() is not null and public.harpatka_is_admin() then jsonb_build_object('status', 'approved', 'can_share', false, 'can_post', true, 'is_admin', true,
      'name', coalesce(nullif(auth.jwt() -> 'user_metadata' ->> 'full_name', ''), auth.jwt() ->> 'email'),
      'first_name', coalesce(nullif(split_part(btrim(coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', '')), ' ', 1), ''), '')) end);
$$;

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
  if adm then perform public.harpatka_ensure_admin_member(); end if;   -- מנהל מפרסם בלי להזין טלפון
  select * into m from public.harpatka_members where user_id = uid;
  if not found then return 'no_member'; end if;
  if m.status in ('blocked', 'removed') then return 'blocked'; end if;
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
