-- עריכת פוסט/תגובה על ידי הכותב. פריט שכבר פורסם: העריכה ממתינה לאישור מנהל (pending_body), עד אז כולם רואים את הנוסח המאושר.
-- פריט שעוד לא פורסם, או עריכה של מנהל: נשמר מיד. אחרי אישור העריכה מופיע "נערך" (edited_at).
alter table public.harpatka_posts add column if not exists edited_at timestamptz;
alter table public.harpatka_posts add column if not exists pending_body text;

insert into public.harpatka_mail_templates (key, subject, html)
select 'post_edit', 'עריכה של {{kind}} ממתינה לאישור',
       replace(replace(html, 'ממתין/ה לאישור</div></div>', 'עודכן/ה ומחכה לאישור</div></div>'), 'לאישור או מחיקה בלוח', 'לאישור העריכה בלוח')
from public.harpatka_mail_templates where key = 'post_pending'
on conflict (key) do nothing;

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
  if not found or m.status = 'blocked' then return 'blocked'; end if;
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
revoke all on function public.harpatka_board_edit(uuid, text) from public;
grant execute on function public.harpatka_board_edit(uuid, text) to authenticated;

-- אישור מנהל: מפרסם את העריכה (מחליף את הנוסח) ומסמן "נערך"
create or replace function public.harpatka_board_approve(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  if not public.harpatka_is_admin() then return 'denied'; end if;
  update public.harpatka_posts set approved_at = coalesce(approved_at, now()),
    edited_at = case when pending_body is not null then now() else edited_at end,
    body = coalesce(pending_body, body), pending_body = null
  where id = p_id returning user_id into uid;
  if uid is null then return 'none'; end if;
  update public.harpatka_members set status = 'approved' where user_id = uid and status = 'pending';
  return 'ok';
end $$;

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
    where p.deleted_at is null
      and (public.harpatka_is_admin() or (m.status <> 'blocked' and ((m.status = 'approved' and p.approved_at is not null) or p.user_id = auth.uid())))
    order by p.created_at desc limit 500
  ) x;
$$;
notify pgrst, 'reload schema';
insert into public.harpatka_mail_templates (key, subject, html)
select 'post_published', '{{kind}} חדש/ה פורסם/ה בלוח השיתופים',
  replace(replace(replace(html, 'ממתין/ה לאישור</div></div>', 'פורסם/ה בלוח</div></div>'), 'לאישור או מחיקה בלוח', 'לצפייה בלוח (אפשר גם למחוק משם)'), '#C96F52;color:#ffffff;text-decoration:none', '#686A48;color:#ffffff;text-decoration:none')
from public.harpatka_mail_templates where key = 'post_pending' on conflict (key) do nothing;
insert into public.harpatka_mail_templates (key, subject, html)
select 'post_edited', '{{kind}} נערך/ה בלוח השיתופים',
  replace(replace(html, 'עודכן/ה ומחכה לאישור</div></div>', 'נערך/ה בלוח</div></div>'), 'לאישור העריכה בלוח', 'לצפייה בלוח')
from public.harpatka_mail_templates where key = 'post_edit' on conflict (key) do nothing;
