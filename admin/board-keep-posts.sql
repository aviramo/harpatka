-- ניתוק/דחייה/מחיקה של משתמש לא מוחקים כלום: הסטטוס הופך ל-removed, הפוסטים והתגובות נשארים מוצגים עם השם שנשמר בעת הפרסום (author_first).
alter table public.harpatka_members drop constraint if exists harpatka_members_status_check;
alter table public.harpatka_members add constraint harpatka_members_status_check check (status in ('pending', 'approved', 'blocked', 'removed'));
alter table public.harpatka_posts add column if not exists author_first text;
update public.harpatka_posts p set author_first = coalesce(nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), '')
  from public.harpatka_members m left join public.harpatka_participants pa on pa.id = m.participant_id where m.user_id = p.user_id and p.author_first is null;
-- הגנה: אי אפשר למחוק חיבור שיש לו פוסטים (בלי מחיקה שרשרתית)
alter table public.harpatka_posts drop constraint if exists harpatka_posts_user_id_fkey;
alter table public.harpatka_posts add constraint harpatka_posts_user_id_fkey foreign key (user_id) references public.harpatka_members(user_id) on delete restrict;

create or replace function public.harpatka_board_feed(p_device uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) from (
    select p.id, p.parent_id, p.root_id, p.created_at,
      case when (p.user_id = auth.uid() or public.harpatka_is_admin()) then coalesce(p.pending_body, p.body) else p.body end as body,
      (p.user_id = auth.uid()) as mine,
      (m.status not in ('approved', 'removed') or p.approved_at is null
        or (p.pending_body is not null and (p.user_id = auth.uid() or public.harpatka_is_admin()))) as pending,
      (p.pending_body is not null and p.approved_at is not null and m.status = 'approved') as pending_edit,
      (p.edited_at is not null) as edited,
      case when p.show_name then coalesce(nullif(p.author_first, ''), nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), '') end as first_name,
      (p.show_name and p.user_id = auth.uid()) as name_shown,
      exists (select 1 from public.harpatka_admins ad where lower(ad.email) = lower(m.email)) as admin_post,
      (p.hidden_at is not null) as hidden,
      (select count(*) from public.harpatka_likes l join public.harpatka_members lm on lm.user_id = l.user_id
         where l.post_id = p.id and (lm.status = 'approved' or l.user_id = auth.uid()))
        + (select count(*) from public.harpatka_anon_likes al where al.post_id = p.id) as likes,
      (exists (select 1 from public.harpatka_likes l where l.post_id = p.id and l.user_id = auth.uid())
        or (p_device is not null and exists (select 1 from public.harpatka_anon_likes al where al.post_id = p.id and al.device_id = p_device))) as liked,
      (public.harpatka_is_admin() or p.user_id = auth.uid() or exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())) as can_delete,
      (public.harpatka_is_admin() and (m.status not in ('approved', 'removed') or p.approved_at is null or p.pending_body is not null)) as can_approve,
      case when public.harpatka_is_admin() then coalesce(pa.name, nullif(m.google_name, ''), m.email)
             || case when pa.id is null then ' (הטלפון ' || m.phone_norm || ' לא נמצא בין המשתתפים)' else '' end end as author,
      (p.share_phone and p.user_id = auth.uid()) as shared,
      case when p.share_phone and p.parent_id is not null and p.approved_at is not null and m.status = 'approved'
                and p.user_id <> auth.uid()
                and exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())
           then regexp_replace(coalesce(nullif(pa.phone_norm, ''), pa.phone), '^\+972', '0') end as phone
    from public.harpatka_posts p
      join public.harpatka_members m on m.user_id = p.user_id
      left join public.harpatka_participants pa on pa.id = m.participant_id
    where p.deleted_at is null and (p.hidden_at is null or public.harpatka_is_admin())
      and (public.harpatka_is_admin() or (m.status <> 'blocked' and ((m.status in ('approved', 'removed') and p.approved_at is not null) or p.user_id = auth.uid())))
    order by p.created_at desc limit 500
  ) x;
$$;

revoke all on function public.harpatka_board_feed(uuid) from public;
grant execute on function public.harpatka_board_feed(uuid) to anon, authenticated;

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
  insert into public.harpatka_posts (id, parent_id, root_id, user_id, body, approved_at, share_phone, show_name, author_first)
  values (new_id, p_parent, coalesce(par.root_id, new_id), uid, body, case when adm or m.status = 'approved' then now() end, share, coalesce(p_show_name, true), coalesce(nullif((select first_name from public.harpatka_participants where id = m.participant_id), ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), ''));   -- משתמש מקושר מתפרסם מיד
  if adm then return 'ok'; end if;
  select value into mail_on from public.harpatka_settings where key = 'mail_v2';
  if mail_on = '1' and p_parent is null then begin   -- מייל למנהלים רק על פוסטים, לא על תגובות
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


create or replace function public.harpatka_board_edit(p_id uuid, p_body text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); p public.harpatka_posts; m public.harpatka_members; pa public.harpatka_participants;
  nb text := btrim(coalesce(p_body, '')); adm boolean := public.harpatka_is_admin(); mail_on text;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into p from public.harpatka_posts where id = p_id and deleted_at is null;
  if not found then return 'none'; end if;
  if p.user_id <> uid then return 'denied'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if not found or m.status in ('blocked', 'removed') then return 'blocked'; end if;
  if nb = '' then return 'empty'; end if;
  if length(nb) > 2000 then return 'long'; end if;
  if nb = p.body and p.pending_body is null then return 'ok'; end if;
  if adm or p.approved_at is null or m.status = 'approved' then
    -- עוד לא פורסם (או מנהל): נשמר מיד; "נערך" רק אם כבר היה מפורסם
    update public.harpatka_posts set body = nb, pending_body = null,
      edited_at = case when p.approved_at is not null and nb <> p.body then now() else p.edited_at end where id = p.id;
    if not adm and p.approved_at is not null and nb <> p.body then
      select value into mail_on from public.harpatka_settings where key = 'mail_v2';
      if mail_on = '1' and p.parent_id is null then begin
        select * into pa from public.harpatka_participants where id = m.participant_id;
        perform public.harpatka_send_mail('post_edited', jsonb_build_object(
          'kind', case when p.parent_id is null then 'פוסט' else 'תגובה' end,
          'body_html', replace(public.harpatka_html_esc(nb), E'
', '<br>'),
          'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
          'identity', coalesce('טלפון ' || pa.phone || ' · ', '') || 'חשבון גוגל ' || m.email,
          'admin_link', 'https://harpatka.co.il/board/', 'hide_link', 'https://harpatka.co.il/board/?hide=' || p.id));
      exception when others then null; end; end if;
    end if;
    return 'ok';
  end if;
  -- פורסם: העריכה ממתינה לאישור; חזרה לנוסח המאושר מבטלת אותה
  update public.harpatka_posts set pending_body = case when nb = p.body then null else nb end where id = p.id;
  if nb <> p.body then
    select value into mail_on from public.harpatka_settings where key = 'mail_v2';
    if mail_on = '1' and p.parent_id is null then begin
      select * into pa from public.harpatka_participants where id = m.participant_id;
      perform public.harpatka_send_mail('post_edit', jsonb_build_object(
        'kind', case when p.parent_id is null then 'פוסט' else 'תגובה' end,
        'body_html', replace(public.harpatka_html_esc(nb), E'\n', '<br>'),
        'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
        'identity', coalesce('טלפון ' || pa.phone || ' · ', '') || 'חשבון גוגל ' || m.email,
        'admin_link', 'https://harpatka.co.il/board/', 'hide_link', 'https://harpatka.co.il/board/?hide=' || p.id));
    exception when others then null; end; end if;
  end if;
  return 'pending';
end $$;

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
  if had and m.status = 'removed' then
    update public.harpatka_members set status = 'pending', phone_norm = case when norm = '' then phone_norm else norm end,
      participant_id = (select id from public.harpatka_participants where phone_norm = norm and active order by created_at limit 1) where user_id = uid;
    perform public.harpatka_notify_member(uid);
    return 'pending';
  end if;
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
notify pgrst, 'reload schema';
