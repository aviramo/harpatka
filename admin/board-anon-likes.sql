-- לב בלי להתחבר: לבבות אנונימיים לפי מזהה מכשיר (נשמר בדפדפן). מי שמחובר ומאושר ממשיך עם לב רגיל.
create table if not exists public.harpatka_anon_likes (
  post_id uuid not null references public.harpatka_posts(id) on delete cascade,
  device_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (post_id, device_id)
);
alter table public.harpatka_anon_likes enable row level security;
revoke all on public.harpatka_anon_likes from anon, authenticated;
drop policy if exists "harpatka admin all" on public.harpatka_anon_likes;
create policy "harpatka admin all" on public.harpatka_anon_likes for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

create or replace function public.harpatka_board_like_anon(p_id uuid, p_device uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if p_device is null then return false; end if;
  if not exists (select 1 from public.harpatka_posts p where p.id = p_id and p.deleted_at is null and p.hidden_at is null and p.approved_at is not null) then return false; end if;
  if exists (select 1 from public.harpatka_anon_likes where post_id = p_id and device_id = p_device) then
    delete from public.harpatka_anon_likes where post_id = p_id and device_id = p_device; return false;
  end if;
  insert into public.harpatka_anon_likes (post_id, device_id) values (p_id, p_device);
  return true;
end $$;
revoke all on function public.harpatka_board_like_anon(uuid, uuid) from public;
grant execute on function public.harpatka_board_like_anon(uuid, uuid) to anon, authenticated;

drop function if exists public.harpatka_board_feed();
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
notify pgrst, 'reload schema';
