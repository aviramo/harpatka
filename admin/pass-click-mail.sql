-- מייל למנהלים בלחיצה על תשלום (11.11.26): גם על מפגש וגם על כרטיסייה. הניסוח: "לחץ על תשלום" ולא "דיווח שילם" (הלחיצה לא מוכיחה שהתשלום בוצע)
-- אידמפוטנטי. __S__ = הסכמה. מריצים קודם על test.
update __S__.harpatka_mail_templates set
  subject = replace(subject, 'דיווח תשלום:', 'לחיצה על תשלום:'),
  html = replace(replace(replace(html, 'דיווח על תשלום ממתין לאישור', 'לחיצה על כפתור התשלום'), 'המשתתף דיווח שהוא שילם. צריך לוודא שהתשלום התקבל ולהזין אותו.', 'המשתתף לחץ על כפתור התשלום בפייבוקס. עוד לא ידוע אם התשלום בוצע: צריך לוודא שהתשלום התקבל ולהזין אותו.'), 'סכום צפוי', 'סכום')
where key = 'payment_reported';

insert into __S__.harpatka_mail_templates (key, subject, html)
select 'pass_pay_clicked', 'לחיצה על תשלום כרטיסייה: {{name}}',
$h$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:6px solid #E5562D;border:1px solid #E8D5BE;border-top:6px solid #E5562D">
<div style="padding:22px 24px 26px">
<div style="font-size:14px;color:#C8411B;font-weight:bold">יוצאים להרפתקה</div>
<div style="font-size:22px;font-weight:bold;color:#2C231D;margin:4px 0 14px">לחיצה על תשלום כרטיסייה</div>
<div style="font-size:26px;font-weight:bold;color:#2C231D;margin-bottom:14px">{{name}}</div>
<div style="font-size:16px;color:#4A3D33;margin-bottom:12px">המשתתף לחץ על כפתור התשלום בפייבוקס של כרטיסייה. עוד לא ידוע אם התשלום בוצע: צריך לוודא שהתשלום התקבל ולהזין אותו ב"קבלת תשלום".</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">כרטיסייה</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#2C231D;font-size:17px;font-weight:bold">{{pass}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">סכום</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#2C231D;font-size:17px;font-weight:bold">{{price}}</td></tr>
</table>
<a href="{{admin_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;margin-top:12px;border-radius:10px">הפרטים בדף הניהול</a>
</div></div></div>$h$
where not exists (select 1 from __S__.harpatka_mail_templates where key = 'pass_pay_clicked');

create or replace function __S__.harpatka_me_buy_pass(p_type uuid, p_n int, p_as uuid default null)
returns text language plpgsql security definer set search_path = __S__, public as $$
declare m __S__.harpatka_members; pid uuid; t __S__.harpatka_meeting_types; pr numeric; pa __S__.harpatka_participants; pn text;
begin
  if p_as is not null then raise exception 'view_only'; end if;
  select * into m from __S__.harpatka_members where user_id = auth.uid();
  if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
  pid := m.participant_id;
  select * into t from __S__.harpatka_meeting_types where id = p_type;
  if not found then return 'not_found'; end if;
  select (x->>'price')::numeric into pr from jsonb_array_elements(coalesce(t.passes, '[]'::jsonb)) x where (x->>'n')::int = p_n limit 1;
  if pr is null then return 'not_found'; end if;
  if exists (select 1 from __S__.harpatka_pass_requests where participant_id = pid and type_id = p_type and n = p_n and status = 'pending' and created_at > now() - interval '1 day') then return 'exists'; end if;
  insert into __S__.harpatka_pass_requests (participant_id, type_id, n, price) values (pid, p_type, p_n, pr);
  begin perform __S__.harpatka_sys_note(pid, 'ביקש/ה לרכוש כרטיסייה ' || p_n || ' מפגשים ב-₪' || trim(to_char(pr, 'FM999990.##')) || ' דרך האזור האישי', 'pass_requested'); exception when others then null; end;
  begin
    select * into pa from __S__.harpatka_participants where id = pid;
    pn := p_n || ' מפגשים' || coalesce(' · ' || nullif(t.name, ''), '');
    perform __S__.harpatka_send_mail('pass_pay_clicked',
      jsonb_build_object('name', coalesce(pa.name, ''), 'pass', pn, 'price', '₪' || trim(to_char(pr, 'FM999990.##')),
        'admin_link', 'https://harpatka.co.il/admin/?p=' || pid), null, null);
  exception when others then null; end;   -- כשל במייל לא מבטל את הבקשה
  return 'ok';
end $$;
revoke all on function __S__.harpatka_me_buy_pass(uuid, int, uuid) from public;
grant execute on function __S__.harpatka_me_buy_pass(uuid, int, uuid) to authenticated;
