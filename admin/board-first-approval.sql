-- אישור ראשוני אחד: מייל אחד למנהלים על התוכן הראשון (פוסט או תגובה) של משתמש שחיבורו עוד לא אושר, ואישור אחד מאשר גם את החיבור וגם את מה שכתב.
-- קישור הטלפון לבדו לא שולח מייל. אחרי האישור המשתמש מקבל מייל שהחיבור אושר.

insert into public.harpatka_mail_templates (key, subject, html) values ('first_pending', 'חיבור חדש ו{{kind}} ראשון בלוח השיתופים ממתינים לאישור', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#686A48;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">לוח השיתופים</div><div style="font-size:22px;font-weight:bold;margin-top:4px">חיבור חדש ו{{kind}} ראשון ממתינים לאישור</div></div>
<div style="padding:22px 24px 26px">
<div style="background:#F6EFE4;border-radius:16px;padding:14px 16px;font-size:18px;line-height:1.5;color:#3F382F">{{{body_html}}}</div>
<div style="margin-top:14px;font-size:15px;color:#3F382F"><b>{{who}}</b></div>
<div style="margin-top:4px;font-size:14px;color:#8A7F72">{{identity}}</div>
<a href="{{approve_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:18px">אישור חיבור ופרסום</a>
<a href="{{hide_link}}" style="display:block;background:#663F4C;color:#ffffff;text-decoration:none;font-weight:bold;font-size:16px;text-align:center;padding:12px 20px;border-radius:999px;margin-top:10px">הסתרה (רק מנהלים יראו)</a>
</div></div></div>$tpl$)
  on conflict (key) do update set subject = excluded.subject, html = excluded.html;

insert into public.harpatka_mail_templates (key, subject, html) values ('member_approved', 'החיבור שלך ללוח השיתופים אושר', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#686A48;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">לוח השיתופים</div><div style="font-size:22px;font-weight:bold;margin-top:4px">החיבור שלך ללוח אושר</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:18px;line-height:1.6;color:#3F382F">מה שכתבת פורסם ומוצג עכשיו לכולם. מעכשיו כל פוסט ותגובה שלך מתפרסמים מיד</div>
<a href="{{board_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:18px">לוח השיתופים</a>
</div></div></div>$tpl$)
  on conflict (key) do update set subject = excluded.subject, html = excluded.html;

CREATE OR REPLACE FUNCTION public.harpatka_board_claim(p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    return 'pending';
  end if;
  if had and (m.participant_id is not null or m.status = 'approved') then return m.status; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id into pid from public.harpatka_participants where phone_norm = norm and active order by created_at limit 1;
  if pid is null and not adm then return 'not_registered'; end if;
  if had then
    update public.harpatka_members set participant_id = pid, phone_norm = norm where user_id = uid;
    return m.status;
  end if;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status)
  values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid,
          case when adm then 'approved' else 'pending' end);
  return case when adm then 'approved' else 'pending' end;
end $function$
;

CREATE OR REPLACE FUNCTION public.harpatka_board_post(p_body text, p_parent uuid DEFAULT NULL::uuid, p_share boolean DEFAULT false, p_show_name boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  first_pending boolean;
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
  first_pending := not adm and m.status <> 'approved' and not exists (select 1 from public.harpatka_posts where user_id = uid and approved_at is null and deleted_at is null);   -- התוכן הראשון שממתין
  share := coalesce(p_share, false) and p_parent is not null and m.participant_id is not null;
  insert into public.harpatka_posts (id, parent_id, root_id, user_id, body, approved_at, share_phone, show_name, author_first)
  values (new_id, p_parent, coalesce(par.root_id, new_id), uid, body, case when adm or m.status = 'approved' then now() end, share, coalesce(p_show_name, true), coalesce(nullif((select first_name from public.harpatka_participants where id = m.participant_id), ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), ''));   -- משתמש מקושר מתפרסם מיד
  if adm then return 'ok'; end if;
  select value into mail_on from public.harpatka_settings where key = 'mail_v2';
  if mail_on = '1' then begin
    select * into pa from public.harpatka_participants where id = m.participant_id;
    if m.status = 'approved' then
      if p_parent is null then   -- למשתמש מאושר: מייל ליידוע על פוסט בלבד
        perform public.harpatka_send_mail('post_published', jsonb_build_object(
          'kind', 'פוסט',
          'body_html', replace(public.harpatka_html_esc(body), E'\n', '<br>') || case when share then '<br><br><i>(המגיב/ה בחר/ה לשתף את הטלפון עם בעל/ת הפוסט)</i>' else '' end,
          'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
          'identity', (case when pa.id is not null then 'משתתף/ת במערכת, טלפון ' || coalesce(pa.phone, '') || ' · חשבון גוגל ' || m.email
                           else 'הטלפון שהוזן (' || m.phone_norm || ') לא נמצא בין המשתתפים · חשבון גוגל ' || m.email end),
          'admin_link', 'https://harpatka.co.il/board/', 'hide_link', 'https://harpatka.co.il/board/?hide=' || new_id));
      end if;
    elsif first_pending then   -- מייל אחד בלבד: החיבור והתוכן הראשון (פוסט או תגובה) מאושרים יחד
      perform public.harpatka_send_mail('first_pending', jsonb_build_object(
        'kind', case when p_parent is null then 'פוסט' else 'תגובה' end,
        'body_html', replace(public.harpatka_html_esc(body), E'\n', '<br>'),
        'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
        'identity', (case when pa.id is not null then 'משתתף/ת במערכת, טלפון ' || coalesce(pa.phone, '') || ' · חשבון גוגל ' || m.email
                         else 'הטלפון שהוזן (' || replace(m.phone_norm, '+972', '0') || ') לא נמצא בין המשתתפים · חשבון גוגל ' || m.email end),
        'approve_link', 'https://harpatka.co.il/board/?approve=' || new_id,
        'hide_link', 'https://harpatka.co.il/board/?hide=' || new_id));
    end if;
  exception when others then null; end; end if;
  return case when m.status = 'approved' then 'ok' else 'pending' end;
end $function$
;

create or replace function public.harpatka_members_publish_pending()
returns trigger language plpgsql security definer set search_path = public as $$
declare mail_on text;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    update public.harpatka_posts set approved_at = now() where user_id = new.user_id and approved_at is null and deleted_at is null;
    if old.status = 'pending' and coalesce(new.email, '') <> '' and not exists (select 1 from public.harpatka_admins a where lower(a.email) = lower(new.email)) then
      begin
        select value into mail_on from public.harpatka_settings where key = 'mail_v2';
        if mail_on = '1' then
          perform public.harpatka_send_mail('member_approved', jsonb_build_object('board_link', 'https://harpatka.co.il/board/'), new.email);
        end if;
      exception when others then null; end;
    end if;
  end if;
  return null;
end $$;
revoke all on function public.harpatka_members_publish_pending() from public, anon, authenticated;
notify pgrst, 'reload schema';
