-- שיתוף טלפון מהמגיב לבעל הפוסט: המגיב מסמן בתגובה "לשתף את הטלפון שלי"; המספר נלקח מהמשתתף המחובר לחשבון שלו
-- (לא מוקלד), ונחשף רק לבעל הפוסט המקורי, ורק מתחת לתגובה הזו, אחרי שהתגובה אושרה.
alter table public.harpatka_posts add column if not exists share_phone boolean not null default false;

create or replace function public.harpatka_board_profile()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', m.status, 'can_share', m.participant_id is not null,
    'can_post', public.harpatka_is_admin() or exists (select 1 from public.harpatka_attendance at where at.participant_id = m.participant_id)) from public.harpatka_members m where m.user_id = auth.uid();
$$;
revoke all on function public.harpatka_board_profile() from public;
grant execute on function public.harpatka_board_profile() to authenticated;

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

create or replace function public.harpatka_board_feed()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) from (
    select p.id, p.parent_id, p.root_id, p.body, p.created_at,
      (p.user_id = auth.uid()) as mine,
      (m.status <> 'approved' or p.approved_at is null) as pending,
      (select count(*) from public.harpatka_likes l join public.harpatka_members lm on lm.user_id = l.user_id
         where l.post_id = p.id and (lm.status = 'approved' or l.user_id = auth.uid())) as likes,
      exists (select 1 from public.harpatka_likes l where l.post_id = p.id and l.user_id = auth.uid()) as liked,
      (public.harpatka_is_admin() or p.user_id = auth.uid() or exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())) as can_delete,
      (public.harpatka_is_admin() and (m.status <> 'approved' or p.approved_at is null)) as can_approve,
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
    where p.deleted_at is null
      and (public.harpatka_is_admin() or (m.status <> 'blocked' and ((m.status = 'approved' and p.approved_at is not null) or p.user_id = auth.uid())))
    order by p.created_at desc limit 500
  ) x;
$$;
revoke all on function public.harpatka_board_feed() from public;
grant execute on function public.harpatka_board_feed() to anon, authenticated;
notify pgrst, 'reload schema';
