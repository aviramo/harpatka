-- הסתרת פוסט/תגובה על ידי מנהל (גם מכפתור במייל): מוסתר מכולם חוץ ממנהלים (גם מהכותב)
alter table public.harpatka_posts add column if not exists hidden_at timestamptz;
create or replace function public.harpatka_board_hide(p_id uuid, p_hide boolean default true)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not public.harpatka_is_admin() then return 'denied'; end if;
  update public.harpatka_posts set hidden_at = case when p_hide then coalesce(hidden_at, now()) else null end where id = p_id and deleted_at is null;
  if not found then return 'none'; end if;
  return 'ok';
end $$;
revoke all on function public.harpatka_board_hide(uuid, boolean) from public;
grant execute on function public.harpatka_board_hide(uuid, boolean) to authenticated;

-- כפתור "הסתרה" במיילים של פוסט חדש/עריכה
update public.harpatka_mail_templates set html = replace(html, E'</a>
</div></div></div>',
  E'</a>
<a href="{{hide_link}}" style="display:block;background:#663F4C;color:#ffffff;text-decoration:none;font-weight:bold;font-size:16px;text-align:center;padding:12px 20px;border-radius:999px;margin-top:10px">הסתרת הפוסט (רק מנהלים יראו אותו)</a>
</div></div></div>')
where key in ('post_pending', 'post_published', 'post_edit', 'post_edited') and html not like '%{{hide_link}}%';

create or replace function public.harpatka_board_feed()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) from (
    select p.id, p.parent_id, p.root_id, p.created_at,
      case when (p.user_id = auth.uid() or public.harpatka_is_admin()) then coalesce(p.pending_body, p.body) else p.body end as body,
      (p.user_id = auth.uid()) as mine,
      (m.status <> 'approved' or p.approved_at is null
        or (p.pending_body is not null and (p.user_id = auth.uid() or public.harpatka_is_admin()))) as pending,
      (p.pending_body is not null and p.approved_at is not null and m.status = 'approved') as pending_edit,
      (p.edited_at is not null) as edited,
      case when p.show_name then coalesce(nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), '') end as first_name,
      (p.show_name and p.user_id = auth.uid()) as name_shown,
      (p.hidden_at is not null) as hidden,
      (select count(*) from public.harpatka_likes l join public.harpatka_members lm on lm.user_id = l.user_id
         where l.post_id = p.id and (lm.status = 'approved' or l.user_id = auth.uid())) as likes,
      exists (select 1 from public.harpatka_likes l where l.post_id = p.id and l.user_id = auth.uid()) as liked,
      (public.harpatka_is_admin() or p.user_id = auth.uid() or exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())) as can_delete,
      (public.harpatka_is_admin() and (m.status <> 'approved' or p.approved_at is null or p.pending_body is not null)) as can_approve,
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
      and (public.harpatka_is_admin() or (m.status <> 'blocked' and ((m.status = 'approved' and p.approved_at is not null) or p.user_id = auth.uid())))
    order by p.created_at desc limit 500
  ) x;
$$;
notify pgrst, 'reload schema';
