-- מגדר במייל ההרשמה החדשה למנהלים
create or replace function public.harpatka_notify_signup(p_name text, p_phone text, p_age int, p_mdate date, p_mtime time, p_pid uuid, p_mid uuid, p_gender text default null)
returns void language plpgsql security definer set search_path = public as $$
declare meeting text; lnk text;
begin
  meeting := case when p_mdate is null then 'אין מפגש קרוב' else to_char(p_mdate, 'DD.MM.YYYY') || coalesce(' · ' || to_char(p_mtime, 'HH24:MI'), '') end;
  lnk := 'https://harpatka.co.il/admin/' || case when p_mid is not null or p_pid is not null then '?' ||
         concat_ws('&', case when p_mid is not null then 'm=' || p_mid end, case when p_pid is not null then 'p=' || p_pid end) else '' end;
  perform public.harpatka_send_mail('signup',
    jsonb_build_object('name', p_name, 'phone', p_phone, 'age', p_age, 'meeting', meeting,
      'gender', case p_gender when 'male' then 'גבר' when 'female' then 'אישה' else 'לא צוין' end,
      'when', to_char(now() at time zone 'Asia/Jerusalem', 'DD.MM.YYYY HH24:MI'),
      'wa_link', 'https://wa.me/' || regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 'admin_link', lnk),
    null,
    jsonb_build_object('name', p_name, 'phone', p_phone, 'age', p_age, 'meeting_date', p_mdate, 'meeting_time', to_char(p_mtime, 'HH24:MI'),
      'created_at', now(), 'participant_id', p_pid, 'meeting_id', p_mid, 'gender', p_gender));
exception when others then null;
end $$;
update public.harpatka_mail_templates set html = replace(html, '{{age}}</td></tr>', '{{age}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מגדר</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{gender}}</td></tr>')
where key = 'signup' and html not like '%{{gender}}%';
