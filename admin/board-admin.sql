-- מנהל (כניסה עם גוגל של מנהל) רואה בלוח עצמו את כל הפוסטים, כולל ממתינים, ויכול לאשר ולמחוק
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
             || case when pa.id is null then ' (הטלפון ' || m.phone_norm || ' לא נמצא בין המשתתפים)' else '' end end as author
    from public.harpatka_posts p
      join public.harpatka_members m on m.user_id = p.user_id
      left join public.harpatka_participants pa on pa.id = m.participant_id
    where p.deleted_at is null
      and (public.harpatka_is_admin() or (m.status <> 'blocked' and ((m.status = 'approved' and p.approved_at is not null) or p.user_id = auth.uid())))
    order by p.created_at desc limit 500
  ) x;
$$;

create or replace function public.harpatka_board_approve(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  if not public.harpatka_is_admin() then return 'denied'; end if;
  update public.harpatka_posts set approved_at = coalesce(approved_at, now()) where id = p_id returning user_id into uid;
  if uid is null then return 'none'; end if;
  update public.harpatka_members set status = 'approved' where user_id = uid and status = 'pending';
  return 'ok';
end $$;

create or replace function public.harpatka_board_delete(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.harpatka_posts;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into p from public.harpatka_posts where id = p_id;
  if not found then return 'none'; end if;
  if not public.harpatka_is_admin() and p.user_id <> uid and not exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = uid) then return 'denied'; end if;
  update public.harpatka_posts set deleted_at = now() where id = p_id;
  return 'ok';
end $$;

revoke all on function public.harpatka_board_approve(uuid) from public;
grant execute on function public.harpatka_board_approve(uuid) to authenticated;

-- המייל מפנה ללוח עצמו
update public.harpatka_mail_templates set html = replace(replace(html, 'לאישור או מחיקה בדף הניהול', 'לאישור או מחיקה בלוח'), 'בדף הניהול', 'בלוח') where key = 'post_pending';
