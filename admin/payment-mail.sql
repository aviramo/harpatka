-- מייל למשתתף כשמפגש שולם (1.11.26): אחרי הקצאה של תשלום למפגש (מהקרדיט או מכל דרך תשלום אחרת) המשתתף מקבל מייל "התשלום התקבל, המקום שלך שמור",
-- ואחרי ניצול חלקי של הקרדיט (נשארה שארית) מייל "התקבל תשלום, נשאר להשלים".
-- * נמען: האימייל של חשבון הגוגל המחובר למשתתף (harpatka_members.email, לא חסום). אין אימייל = אין מייל (אין שדה אימייל בהרשמה).
-- * מייל "התשלום התקבל": פעם אחת לכל מפגש (harpatka_attendance.pay_mail_sent_at), רק כשאין שארית (pay_due_amount) ולא במפגש חינם. טריגר דחוי (בסוף הטרנזקציה), כך שכמה הקצאות באותה פעולה = מייל אחד עם הסכום המצטבר.
-- * ניצול קרדיט של המשתתף עצמו (harpatka_me_pay_credit) שולח את המייל בעצמו (עם דגל harpatka.skip_pay_mail שמדלג על הטריגר), כי רק הוא יודע אם נשארה שארית.
-- * תוכן: שם פרטי, שם המפגש (או שם הסוג), יום ותאריך ושעה, עיר ומיקום, מה שולם ובאיזו דרך (קרדיט, פייבוקס, ביט...), כמה קרדיט נשאר, הוראות ההגעה (כולל הקישור לתמונה או לסרטון), קישור לאזור האישי, וואטסאפ להדר ולאופיר.
-- מחליף את harpatka_me_pay_credit מ-me-pay-credit.sql (אותה פונקציה, עם שליחת המייל): להריץ אחרי me-pay-credit.sql.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public ו-__ADM__ בפונקציית בדיקת המנהל (test: harpatka_is_admin_site, public: harpatka_is_admin):
--   sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin_site/g' admin/payment-mail.sql | supabase db query --linked
--   sed 's/__S__/public/g; s/__ADM__/harpatka_is_admin/g' admin/payment-mail.sql | supabase db query --linked
alter table __S__.harpatka_attendance add column if not exists pay_mail_sent_at timestamptz;

create or replace function __S__.harpatka_pm_esc(t text) returns text language sql immutable as $f$
  select replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;')
$f$;

-- בונה ושולח את המייל. p_partial = שארית (p_rem) אחרי ניצול חלקי של הקרדיט. p_to: נמען מפורש (בדיקות); אחרת האימייל של חשבון הגוגל. מחזיר true כשנשלח
create or replace function __S__.harpatka_pay_mail(p_pid uuid, p_mid uuid, p_partial boolean default false, p_rem numeric default null, p_to text default null)
returns boolean language plpgsql security definer set search_path = __S__, public as $f$
declare
  em text := lower(nullif(trim(p_to), '')); mt __S__.harpatka_meetings; pa __S__.harpatka_participants;
  days text[] := array['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  nm text; whn text; wh text; dirs text; dh text; cr numeric; bal numeric; parts text[] := '{}'; r record; vars jsonb; paid_txt text;
  name_b text := ''; where_b text := ''; credit_b text := ''; dir_b text := '';
begin
  if em is null then
    select lower(m.email) into em from __S__.harpatka_members m where m.participant_id = p_pid and coalesce(m.email, '') <> '' and m.status <> 'blocked' order by (m.status = 'approved') desc limit 1;
  end if;
  select * into mt from __S__.harpatka_meetings where id = p_mid; if not found then return false; end if;
  if mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return false; end if;   -- מפגש שעבר: בלי מייל
  select * into pa from __S__.harpatka_participants where id = p_pid; if not found then return false; end if;
  nm := coalesce(nullif(trim(mt.name), ''), (select nullif(trim(t.name), '') from __S__.harpatka_meeting_types t where t.id = mt.type_id), '');
  whn := 'יום ' || days[extract(dow from mt.meeting_date)::int + 1] || ' ' || to_char(mt.meeting_date, 'FMDD.FMMM') || ' · ' || to_char(mt.meeting_time, 'HH24:MI');
  wh := concat_ws(' · ', nullif(trim(mt.city), ''), nullif(trim(mt.place), ''));
  if nm <> '' then name_b := '<div style="font-size:15px;color:#4A3D33;margin-bottom:4px">' || __S__.harpatka_pm_esc(nm) || '</div>'; end if;
  if wh <> '' then where_b := '<div style="font-size:15px;color:#4A3D33;margin-top:4px">' || __S__.harpatka_pm_esc(wh) || '</div>'; end if;
  -- מה שולם: מהקרדיט, ולפי דרך תשלום (פייבוקס, ביט, מזומן...)
  select coalesce(sum(case when p.from_credit then p.amount else 0 end), 0) into cr from __S__.harpatka_payments p where p.participant_id = p_pid and p.meeting_id = p_mid and p.kind = 'payment';
  if cr > 0 then parts := parts || ('₪' || trim_scale(cr)::text || ' מהקרדיט'); end if;
  for r in select pm.name as mname, sum(p.amount) as amt from __S__.harpatka_payments p left join __S__.harpatka_pay_methods pm on pm.key = p.method
            where p.participant_id = p_pid and p.meeting_id = p_mid and p.kind = 'payment' and not coalesce(p.from_credit, false) group by pm.name order by pm.name loop
    parts := parts || ('₪' || trim_scale(r.amt)::text || case when coalesce(r.mname, '') = '' then '' else ' ב' || r.mname end);
  end loop;
  paid_txt := array_to_string(parts, ' · ');
  if cr > 0 then
    select coalesce(sum(case when kind in ('credit', 'deposit') then amount when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0) into bal from __S__.harpatka_payments where participant_id = p_pid;
    if bal > 0 then credit_b := '<div style="font-size:15px;color:#4A3D33;margin-top:4px">נשאר לך קרדיט של ₪' || trim_scale(bal)::text || '</div>'; end if;
  end if;
  -- הוראות הגעה: טקסט מוגן, שורות, וקישור לתמונה או לסרטון כ"לפתיחה"
  dir_b := __S__.harpatka_mail_directions(p_mid);
  vars := jsonb_build_object('_pid', p_pid, '_mid', p_mid, 'first_name', coalesce(nullif(pa.first_name, ''), pa.name, ''), 'when', whn, 'paid', paid_txt, 'rem', coalesce('₪' || trim_scale(p_rem)::text, ''),
    'name_block', name_b, 'where_block', where_b, 'credit_block', credit_b, 'dir_block', dir_b,
    'me_link', 'https://harpatka.co.il/me/?m=' || p_mid, 'wa_hadar', 'https://wa.me/972546163012', 'wa_ofir', 'https://wa.me/972587078708');
  if em is null then
    perform __S__.harpatka_mail_record(case when p_partial then 'payment_partial' else 'payment_confirmed' end, vars, null, null, null, 'failed', 'אין אימייל, המשתתף לא מחובר לחשבון גוגל');
    return false;
  end if;
  perform __S__.harpatka_send_mail(case when p_partial then 'payment_partial' else 'payment_confirmed' end, vars, em);
  return true;
exception when others then
  return false;   -- כשל במייל לא מבטל את התשלום
end $f$;
revoke all on function __S__.harpatka_pay_mail(uuid, uuid, boolean, numeric, text) from public, anon, authenticated;

-- הטריגר: אחרי הקצאת תשלום למפגש (כל דרך), בסוף הטרנזקציה
create or replace function __S__.harpatka_pay_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare a __S__.harpatka_attendance; net numeric;
begin
  if new.kind <> 'payment' or new.meeting_id is null then return null; end if;
  if coalesce(current_setting('harpatka.skip_pay_mail', true), '') = '1' then return null; end if;   -- ניצול קרדיט של המשתתף עצמו שולח בעצמו
  select * into a from __S__.harpatka_attendance where participant_id = new.participant_id and meeting_id = new.meeting_id;
  if not found or coalesce(a.no_pay, false) or a.pay_mail_sent_at is not null or coalesce(a.pay_due_amount, 0) > 0 then return null; end if;
  select coalesce(sum(case when kind = 'payment' then amount when kind = 'credit' or (kind = 'refund' and not coalesce(from_credit, false)) then -amount else 0 end), 0) into net
    from __S__.harpatka_payments where participant_id = new.participant_id and meeting_id = new.meeting_id;
  if net <= 0 then return null; end if;
  if __S__.harpatka_pay_mail(new.participant_id, new.meeting_id) then
    update __S__.harpatka_attendance set pay_mail_sent_at = now() where participant_id = new.participant_id and meeting_id = new.meeting_id;
  end if;
  return null;
exception when others then return null;
end $f$;
drop trigger if exists harpatka_pay_mail on __S__.harpatka_payments;
create constraint trigger harpatka_pay_mail after insert on __S__.harpatka_payments deferrable initially deferred for each row execute function __S__.harpatka_pay_mail_fn();

-- ניצול קרדיט של המשתתף עצמו (כמו ב-me-pay-credit.sql) + המייל
create or replace function __S__.harpatka_me_pay_credit(p_meeting uuid, p_as uuid default null)
returns jsonb language plpgsql security definer set search_path = __S__, public as $f$
declare
  m __S__.harpatka_members; pid uuid; mt __S__.harpatka_meetings; a __S__.harpatka_attendance; pa __S__.harpatka_participants;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  price numeric; paid numeric; due numeric; bal numeric; amt numeric; rem numeric;
begin
  if p_as is not null then
    if not __S__.__ADM__() then raise exception 'forbidden'; end if;   -- מנהל פועל במקום המשתתף (התחזות)
    pid := p_as;
  else
    select * into m from __S__.harpatka_members where user_id = auth.uid();
    if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
    pid := m.participant_id;
  end if;
  select * into mt from __S__.harpatka_meetings where id = p_meeting;
  if not found then return jsonb_build_object('status', 'missing'); end if;
  select * into a from __S__.harpatka_attendance where participant_id = pid and meeting_id = p_meeting;
  if not found then return jsonb_build_object('status', 'not_registered'); end if;
  if coalesce(a.no_pay, false) then return jsonb_build_object('status', 'free'); end if;
  select coalesce(sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end), 0)
    into paid from __S__.harpatka_payments p where p.participant_id = pid and p.meeting_id = p_meeting;
  if paid > 0 then return jsonb_build_object('status', 'already'); end if;
  price := __S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0));
  due := greatest(coalesce(price, 0), 0);
  if due <= 0 then return jsonb_build_object('status', 'already'); end if;
  select coalesce(sum(case when kind in ('credit', 'deposit') then amount when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0)
    into bal from __S__.harpatka_payments where participant_id = pid;
  if bal <= 0 then return jsonb_build_object('status', 'no_credit'); end if;
  amt := least(bal, due);
  select * into pa from __S__.harpatka_participants where id = pid;
  perform set_config('harpatka.skip_pay_mail', '1', true);   -- המייל נשלח כאן (יודעים אם נשארה שארית), לא בטריגר
  insert into __S__.harpatka_payments (participant_id, meeting_id, kind, amount, from_credit, author_name)
    values (pid, p_meeting, 'payment', amt, true, coalesce(nullif(pa.name, ''), 'משתתף'));
  rem := due - amt;
  if rem > 0 then update __S__.harpatka_attendance set pay_due_amount = rem where participant_id = pid and meeting_id = p_meeting; end if;
  begin
    if rem <= 0 and __S__.harpatka_pay_mail(pid, p_meeting) then update __S__.harpatka_attendance set pay_mail_sent_at = now() where participant_id = pid and meeting_id = p_meeting;
    end if;
  exception when others then null;
  end;
  return jsonb_build_object('status', 'ok', 'allocated', amt, 'remaining', rem, 'credit_left', bal - amt);
end $f$;
revoke all on function __S__.harpatka_me_pay_credit(uuid, uuid) from public;
grant execute on function __S__.harpatka_me_pay_credit(uuid, uuid) to authenticated;

-- התבניות (אפשר לערוך בטבלה harpatka_mail_templates; הרצה חוזרת של הקובץ מחזירה לנוסח הזה)
insert into __S__.harpatka_mail_templates (key, subject, html) values ('payment_confirmed', 'התשלום התקבל, המקום שלך שמור', $h$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">שלום {{first_name}},</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">התשלום התקבל, והמקום שלך במפגש נשמר.</div>
<div style="border:1px solid #FFD8AE;background:#FFF5E8;padding:14px 16px;margin-bottom:16px">{{{name_block}}}<div style="font-size:19px;font-weight:bold;color:#2C231D">{{when}}</div>{{{where_block}}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:18px"><b>שולם:</b> {{paid}}{{{credit_block}}}</div>
{{{dir_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">נתראה, אופיר והדר</div>
</div></div></div>$h$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

insert into __S__.harpatka_mail_templates (key, subject, html) values ('payment_partial', 'התקבל תשלום, נשאר להשלים {{rem}}', $h$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div><div style="font-size:24px;font-weight:bold;color:#2C231D;margin-top:8px;line-height:1.3">התקבל תשלום, נשאר להשלים</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">שלום {{first_name}},</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">התקבל {{paid}} על המפגש. נשאר להשלים {{rem}}, והמקום שלך יישמר קבוע רק אחרי השלמת התשלום.</div>
<div style="border:1px solid #FFD8AE;background:#FFF5E8;padding:14px 16px;margin-bottom:18px">{{{name_block}}}<div style="font-size:19px;font-weight:bold;color:#2C231D">{{when}}</div>{{{where_block}}}</div>
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">להשלמת התשלום באזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">רוצה לשלם בדרך אחרת, או יש שאלה? אפשר לכתוב לנו בוואטסאפ: <a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">נתראה,<br>אופיר והדר</div>
</div></div></div>$h$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;
notify pgrst, 'reload schema';
