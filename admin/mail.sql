-- ==========================================================================
-- מנגנון מיילים גנרי + אישור כל פוסט/תגובה בלוח השיתופים
--
-- 1. טבלת טמפלטים harpatka_mail_templates (מפתח, נושא, HTML עם {{משתנים}}). טמפלט חדש = שורה חדשה, בלי לגעת ב-Apps Script.
--    {{x}} נכנס עם escape ל-HTML; {{{x}}} נכנס כמו שהוא (HTML מוכן).
-- 2. harpatka_send_mail(key, vars, to?, extra?): מרנדר ושולח דרך ה-Apps Script הגנרי (admin/notify-apps-script.gs).
--    נמענים: הפרמטר to, אחרת העמודה to_addr בטמפלט, אחרת ההגדרה mail_to, אחרת ברירת המחדל בסקריפט.
-- 3. כל פוסט/תגובה בלוח ממתין לאישור מנהל (approved_at); מנהלים מאושרים אוטומטית; מייל לכל פריט שממתין.
-- להריץ פעם אחת (אפשר שוב בלי נזק, חוץ מטמפלטים שכבר קיימים: לא נדרסים).
-- ==========================================================================

create table if not exists public.harpatka_mail_templates (
  key        text primary key,
  to_addr    text,
  subject    text not null,
  html       text not null,
  updated_at timestamptz not null default now()
);
alter table public.harpatka_mail_templates enable row level security;
revoke all on public.harpatka_mail_templates from anon, authenticated;
drop policy if exists "harpatka admin all" on public.harpatka_mail_templates;
create policy "harpatka admin all" on public.harpatka_mail_templates for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

create or replace function public.harpatka_html_esc(s text)
returns text language sql immutable as $$
  select replace(replace(replace(replace(replace(coalesce(s, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '''', '&#39;');
$$;

create or replace function public.harpatka_render(tpl text, vars jsonb, esc boolean default true)
returns text language plpgsql immutable as $$
declare k text; v text; o text := coalesce(tpl, '');
begin
  for k, v in select key, value from jsonb_each_text(coalesce(vars, '{}'::jsonb)) loop
    o := replace(o, '{{{' || k || '}}}', coalesce(v, ''));
    o := replace(o, '{{' || k || '}}', case when esc then public.harpatka_html_esc(v) else coalesce(v, '') end);
  end loop;
  return o;
end $$;

create or replace function public.harpatka_send_mail(p_key text, p_vars jsonb default '{}', p_to text default null, p_extra jsonb default '{}')
returns void language plpgsql security definer set search_path = public as $$
declare u text; tok text; t public.harpatka_mail_templates; dflt text; recip text;
begin
  select value into u   from public.harpatka_settings where key = 'notify_url';
  select value into tok from public.harpatka_settings where key = 'notify_token';
  select value into dflt from public.harpatka_settings where key = 'mail_to';
  if coalesce(u, '') = '' then return; end if;
  select * into t from public.harpatka_mail_templates where key = p_key;
  if not found then return; end if;
  recip := coalesce(nullif(p_to, ''), nullif(t.to_addr, ''), nullif(dflt, ''));
  perform net.http_post(
    url := u,
    body := coalesce(p_extra, '{}'::jsonb) || jsonb_build_object('token', tok, 'to', recip,
              'subject', public.harpatka_render(t.subject, p_vars, false), 'html', public.harpatka_render(t.html, p_vars, true)),
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 30000);
exception when others then
  null;   -- כשל במייל לא מפיל את הפעולה שהפעילה אותו
end $$;
revoke all on function public.harpatka_send_mail(text, jsonb, text, jsonb) from public, anon, authenticated;

-- ---------- טמפלטים ----------
insert into public.harpatka_mail_templates (key, subject, html) values
('signup', 'הרשמה חדשה מהאתר: {{name}}', $t$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#C96F52;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div><div style="font-size:22px;font-weight:bold;margin-top:4px">הרשמה חדשה מהאתר</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:26px;font-weight:bold;color:#3F382F;margin-bottom:14px">{{name}}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px;width:34%">טלפון</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold"><span dir="ltr" style="unicode-bidi:embed">{{phone}}</span></td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">גיל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{age}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מפגש</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{meeting}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">נרשם/ה ב</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{when}}</td></tr>
</table>
<a href="{{wa_link}}" style="display:block;background:#25A55F;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">שליחת וואטסאפ</a>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">הפרטים בדף הניהול</a>
</div></div></div>$t$),
('post_pending', '{{kind}} חדש/ה בלוח השיתופים ממתין/ה לאישור', $t$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#686A48;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">לוח השיתופים</div><div style="font-size:22px;font-weight:bold;margin-top:4px">{{kind}} חדש/ה ממתין/ה לאישור</div></div>
<div style="padding:22px 24px 26px">
<div style="background:#F6EFE4;border-radius:16px;padding:14px 16px;font-size:18px;line-height:1.5;color:#3F382F">{{{body_html}}}</div>
<div style="margin-top:14px;font-size:15px;color:#3F382F"><b>{{who}}</b></div>
<div style="margin-top:4px;font-size:14px;color:#8A7F72">{{identity}}</div>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:18px">לאישור או מחיקה בדף הניהול</a>
</div></div></div>$t$)
on conflict (key) do nothing;

-- ---------- התראת הרשמה: עכשיו דרך הטמפלט (אותה חתימה, כך ש-harpatka_signup לא משתנה). נשארים גם השדות הישנים בשליחה, כדי שסקריפט ישן ימשיך לעבוד עד שמעדכנים אותו ----------
create or replace function public.harpatka_notify_signup(p_name text, p_phone text, p_age int, p_mdate date, p_mtime time, p_pid uuid, p_mid uuid, p_gender text default null)
returns void language plpgsql security definer set search_path = public as $$
declare meeting text; lnk text;
begin
  meeting := case when p_mdate is null then 'אין מפגש קרוב' else to_char(p_mdate, 'DD.MM.YYYY') || coalesce(' · ' || to_char(p_mtime, 'HH24:MI'), '') end;
  lnk := 'https://harpatka.co.il/admin/' || case when p_mid is not null or p_pid is not null then '?' ||
         concat_ws('&', case when p_mid is not null then 'm=' || p_mid end, case when p_pid is not null then 'p=' || p_pid end) else '' end;
  perform public.harpatka_send_mail('signup',
    jsonb_build_object('name', p_name, 'phone', p_phone, 'age', p_age, 'meeting', meeting,
      'when', to_char(now() at time zone 'Asia/Jerusalem', 'DD.MM.YYYY HH24:MI'),
      'wa_link', 'https://wa.me/' || regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 'admin_link', lnk),
    null,
    jsonb_build_object('name', p_name, 'phone', p_phone, 'age', p_age, 'meeting_date', p_mdate, 'meeting_time', to_char(p_mtime, 'HH24:MI'),
      'created_at', now(), 'participant_id', p_pid, 'meeting_id', p_mid, 'gender', p_gender));
exception when others then null;
end $$;
revoke all on function public.harpatka_notify_signup(text, text, int, date, time, uuid, uuid, text) from public, anon, authenticated;

-- ---------- לוח שיתופים: אישור כל פריט ----------
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'harpatka_posts' and column_name = 'approved_at') then
    alter table public.harpatka_posts add column approved_at timestamptz;
    update public.harpatka_posts set approved_at = created_at;   -- מה שכבר קיים נחשב מאושר
  end if;
end $$;

create or replace function public.harpatka_board_claim(p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  m public.harpatka_members;
  pid uuid;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if found then return m.status; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id into pid from public.harpatka_participants where phone_norm = norm order by created_at limit 1;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status)
  values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid,
          case when public.harpatka_is_admin() then 'approved' else 'pending' end);
  return case when public.harpatka_is_admin() then 'approved' else 'pending' end;
end $$;

create or replace function public.harpatka_board_feed()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) from (
    select p.id, p.parent_id, p.root_id, p.body, p.created_at,
      (p.user_id = auth.uid()) as mine,
      (m.status <> 'approved' or p.approved_at is null) as pending,
      (select count(*) from public.harpatka_likes l join public.harpatka_members lm on lm.user_id = l.user_id
         where l.post_id = p.id and (lm.status = 'approved' or l.user_id = auth.uid())) as likes,
      exists (select 1 from public.harpatka_likes l where l.post_id = p.id and l.user_id = auth.uid()) as liked,
      (p.user_id = auth.uid() or exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())) as can_delete
    from public.harpatka_posts p join public.harpatka_members m on m.user_id = p.user_id
    where p.deleted_at is null and m.status <> 'blocked'
      and ((m.status = 'approved' and p.approved_at is not null) or p.user_id = auth.uid())
    order by p.created_at desc limit 500
  ) x;
$$;

-- החזרה: 'ok' (פורסם, מנהל) או 'pending' (ממתין לאישור)
create or replace function public.harpatka_board_post(p_body text, p_parent uuid default null)
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
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if not found then return 'no_member'; end if;
  if m.status = 'blocked' then return 'blocked'; end if;
  if body = '' then return 'empty'; end if;
  if length(body) > 2000 then return 'long'; end if;
  if not adm and (select count(*) from public.harpatka_posts where user_id = uid and deleted_at is null and approved_at is null) >= 5 then return 'limit'; end if;
  if p_parent is not null then
    select * into par from public.harpatka_posts where id = p_parent and deleted_at is null;
    if not found then return 'no_parent'; end if;
    select * into pm from public.harpatka_members where user_id = par.user_id;
    if (pm.status <> 'approved' or par.approved_at is null) and par.user_id <> uid then return 'no_parent'; end if;
  end if;
  insert into public.harpatka_posts (id, parent_id, root_id, user_id, body, approved_at)
  values (new_id, p_parent, coalesce(par.root_id, new_id), uid, body, case when adm then now() end);
  if adm then return 'ok'; end if;
  select value into mail_on from public.harpatka_settings where key = 'mail_v2';
  if mail_on = '1' then begin
    select * into pa from public.harpatka_participants where id = m.participant_id;
    perform public.harpatka_send_mail('post_pending', jsonb_build_object(
      'kind', case when p_parent is null then 'פוסט' else 'תגובה' end,
      'body_html', replace(public.harpatka_html_esc(body), E'\n', '<br>'),
      'who', coalesce(pa.name, nullif(m.google_name, ''), m.email),
      'identity', case when pa.id is not null then 'משתתף/ת במערכת, טלפון ' || coalesce(pa.phone, '') || ' · חשבון גוגל ' || m.email
                       else 'הטלפון שהוזן (' || m.phone_norm || ') לא נמצא בין המשתתפים · חשבון גוגל ' || m.email end,
      'admin_link', 'https://harpatka.co.il/board/'));
  exception when others then null; end; end if;
  return 'pending';
end $$;

revoke all on function public.harpatka_board_claim(text), public.harpatka_board_feed(), public.harpatka_board_post(text, uuid) from public;
grant execute on function public.harpatka_board_feed() to anon, authenticated;
grant execute on function public.harpatka_board_claim(text), public.harpatka_board_post(text, uuid) to authenticated;

notify pgrst, 'reload schema';
