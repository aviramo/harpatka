-- חיבור טלפון ללוח: רק מספר של משתתף רשום. מספר שלא נמצא = 'not_registered' (בלי ליצור חיבור), והמשתמש מתבקש להירשם למפגש תחילה.
-- חיבור קיים בלי משתתף (מלפני השינוי) מקבל הזדמנות לנסות שוב.
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
revoke all on function public.harpatka_board_claim(text) from public;
grant execute on function public.harpatka_board_claim(text) to authenticated;

-- מייל למנהלים: בקשת חיבור חדשה (חשבון גוגל + טלפון) שממתינה לאישור. סוג מייל נפרד ממייל פוסט חדש.
insert into public.harpatka_mail_templates (key, subject, html) values
('member_pending', 'בקשת חיבור חדשה ללוח השיתופים ממתינה לאישור', $t$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#663F4C;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">לוח השיתופים</div><div style="font-size:22px;font-weight:bold;margin-top:4px">בקשת חיבור חדשה</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:24px;font-weight:bold;color:#3F382F;margin-bottom:12px">{{name}}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px;width:34%">חשבון גוגל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:16px;font-weight:bold">{{email}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">טלפון שהוזן</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:16px;font-weight:bold"><span dir="ltr" style="unicode-bidi:embed">{{phone}}</span></td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">משתתף במערכת</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:16px;font-weight:bold">{{match}}</td></tr>
</table>
<div style="margin-top:12px;font-size:14px;color:#8A7F72">יש להשוות בין שם חשבון הגוגל לשם המשתתף ולאשר או לדחות</div>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:18px">לאישור החיבור בדף הניהול</a>
</div></div></div>$t$)
on conflict (key) do nothing;

create or replace function public.harpatka_notify_member(p_uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m public.harpatka_members; pa public.harpatka_participants; mail_on text;
begin
  select value into mail_on from public.harpatka_settings where key = 'mail_v2';
  if mail_on is distinct from '1' then return; end if;
  select * into m from public.harpatka_members where user_id = p_uid;
  if not found then return; end if;
  select * into pa from public.harpatka_participants where id = m.participant_id;
  perform public.harpatka_send_mail('member_pending', jsonb_build_object(
    'name', coalesce(nullif(m.google_name, ''), m.email), 'email', m.email, 'phone', replace(m.phone_norm, '+972', '0'),
    'match', case when pa.id is not null then pa.name else 'הטלפון לא נמצא בין המשתתפים' end,
    'admin_link', 'https://harpatka.co.il/admin/?bd=1'));
exception when others then null;
end $$;
revoke all on function public.harpatka_notify_member(uuid) from public, anon, authenticated;
