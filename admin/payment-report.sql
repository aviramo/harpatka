-- דיווח תשלום מהאזור האישי (28.10.26): המשתתף לוחץ "דיווחתי על תשלום" אחרי התשלום בפייבוקס, והשיוך שלו למפגש עובר לסטטוס "דיווח תשלום"
-- (סטטוס מפגש רגיל, תווית בלבד, מפתח m_reported) עד שאחד המנהלים מוודא ומזין את התשלום כרגיל. המנהלים מקבלים מייל עם קישור לפרטי המשתתף.
-- אידמפוטנטי; להריץ על public, ואז admin/test-site.sql (מעתיק את הפונקציות ל-test). את הסטטוס מוסיפים בשתי הסכמות (למטה).

-- סטטוס "דיווח תשלום": בין "שוריין" ל"חדש" (חדש תמיד ראשון בהגדרות ובעל sort 99)
insert into public.harpatka_statuses (key, label, color, sort, scope, phase)
select 'm_reported', 'דיווח תשלום', 'amber', 4, 'meeting', 'before'
where not exists (select 1 from public.harpatka_statuses where key = 'm_reported');
insert into test.harpatka_statuses (key, label, color, sort, scope, phase)
select 'm_reported', 'דיווח תשלום', 'amber', 4, 'meeting', 'before'
where not exists (select 1 from test.harpatka_statuses where key = 'm_reported');

-- מייל למנהלים (נמען ברירת מחדל: mail_to)
insert into public.harpatka_mail_templates (key, subject, html)
select 'payment_reported', 'דיווח תשלום: {{name}}',
$h$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#C96F52;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div><div style="font-size:22px;font-weight:bold;margin-top:4px">דיווח על תשלום ממתין לאישור</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:26px;font-weight:bold;color:#3F382F;margin-bottom:14px">{{name}}</div>
<div style="font-size:16px;color:#3F382F;margin-bottom:12px">המשתתף דיווח שהוא שילם. צריך לוודא שהתשלום התקבל ולהזין אותו.</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מפגש</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{meeting}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">סכום צפוי</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{price}}</td></tr>
</table>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">הפרטים בדף הניהול</a>
</div></div></div>$h$
where not exists (select 1 from public.harpatka_mail_templates where key = 'payment_reported');

-- הפונקציה: מסמנת את השיוך כ"דיווח תשלום" ושולחת מייל. מנהל בהתחזות (p_as) יכול לדווח בשם המשתתף
create or replace function public.harpatka_me_report_payment(p_meeting uuid, p_as uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  m public.harpatka_members; pid uuid; mt public.harpatka_meetings; a public.harpatka_attendance; pa public.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date; paid numeric;
begin
  if p_as is not null then
    if not public.harpatka_is_admin() then raise exception 'forbidden'; end if;
    pid := p_as;
  else
    select * into m from public.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  select * into mt from public.harpatka_meetings where id = p_meeting;
  if not found or mt.meeting_date < today then return 'past'; end if;
  select * into a from public.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return 'not_registered'; end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  if paid > 0 or coalesce(a.no_pay, false) then return 'already'; end if;
  if a.status_key = 'm_reported' then return 'reported'; end if;
  update public.harpatka_attendance set status_key = 'm_reported' where participant_id = pid and meeting_id = p_meeting;
  select * into pa from public.harpatka_participants where id = pid;
  perform public.harpatka_send_mail('payment_reported',
    jsonb_build_object('name', coalesce(pa.name, ''), 'meeting', to_char(mt.meeting_date, 'DD.MM.YYYY') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || coalesce(' · ' || nullif(mt.city, ''), ''),
      'price', coalesce('₪' || public.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today)::text, ''),
      'admin_link', 'https://harpatka.co.il/admin/?m=' || p_meeting || '&p=' || pid), null, null);
  return 'ok';
exception when others then
  if sqlerrm in ('forbidden', 'auth') then raise; end if;
  return 'ok';   -- כשל במייל לא מבטל את הדיווח
end $$;
revoke all on function public.harpatka_me_report_payment(uuid, uuid) from public;
grant execute on function public.harpatka_me_report_payment(uuid, uuid) to authenticated;
