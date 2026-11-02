-- מיילים למשתתף על החזר כסף ועל הסרה ממפגש (2.11.26). מריצים אחרי mail-log.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-refund-removed.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-refund-removed.sql | supabase db query --linked
-- * החזר: כל רשומת refund ביומן התשלומים (גם מהיתרה וגם ישירות ממפגש). נקשר להערת "הוחזרו".
-- * הסרה: כל מחיקת שיוך למפגש, גם של מנהל וגם ביטול רישום של המשתתף עצמו. לא במפגש שכבר עבר. נקשר להערת ההסרה.
-- * בלי אימייל (לא מחובר לגוגל): לא נשלח, ובהערה מופיע "המייל לא נשלח", כמו בכל מייל.
insert into __S__.harpatka_mail_templates (key, subject, html) values ('payment_refunded', 'החזרנו לך {{amount}}', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">{{hello}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">החזרנו לך {{amount}}{{how}}.</div>
{{{meeting_block}}}{{{credit_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">להתראות, אופיר והדר</div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

insert into __S__.harpatka_mail_templates (key, subject, html) values ('meeting_removed', 'הרישום שלך למפגש בוטל', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">{{hello}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">הרישום שלך למפגש הזה בוטל:</div>
{{{meeting_block}}}{{{credit_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות, או שזו טעות? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">להתראות, אופיר והדר</div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

-- החלקים המשותפים של מיילים למשתתף: פנייה, פרטי מפגש, קרדיט שנשאר וקישורים
create or replace function __S__.harpatka_mail_common(p_pid uuid, p_mid uuid)
returns jsonb language plpgsql security definer set search_path = __S__, public as $f$
declare
  pa __S__.harpatka_participants; mt __S__.harpatka_meetings; bal numeric; nm text; wh text; first text;
  days text[] := array['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  mb text := ''; cb text := '';
begin
  select * into pa from __S__.harpatka_participants where id = p_pid;
  first := coalesce(nullif(trim(pa.first_name), ''), nullif(trim(pa.name), ''), '');
  if p_mid is not null then
    select * into mt from __S__.harpatka_meetings where id = p_mid;
    if found then
      nm := coalesce(nullif(trim(mt.name), ''), (select nullif(trim(t.name), '') from __S__.harpatka_meeting_types t where t.id = mt.type_id), '');
      wh := concat_ws(' · ', nullif(trim(mt.city), ''), nullif(trim(mt.place), ''));
      mb := '<div style="border:1px solid #FFD8AE;background:#FFF5E8;padding:14px 16px;margin-bottom:16px">'
        || case when nm <> '' then '<div style="font-size:15px;color:#4A3D33;margin-bottom:4px">' || __S__.harpatka_pm_esc(nm) || '</div>' else '' end
        || '<div style="font-size:19px;font-weight:bold;color:#2C231D">יום ' || days[extract(dow from mt.meeting_date)::int + 1] || ' ' || to_char(mt.meeting_date, 'FMDD.FMMM') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || '</div>'
        || case when wh <> '' then '<div style="font-size:15px;color:#4A3D33;margin-top:4px">' || __S__.harpatka_pm_esc(wh) || '</div>' else '' end
        || '</div>';
    end if;
  end if;
  select coalesce(sum(case when kind in ('credit', 'deposit') then amount when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0) into bal
    from __S__.harpatka_payments where participant_id = p_pid;
  if bal > 0 then cb := '<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:18px">יש לך קרדיט של ₪' || trim_scale(bal)::text || ', ואפשר להשתמש בו במפגש הבא.</div>'; end if;
  return jsonb_build_object('_pid', p_pid, '_mid', p_mid, 'hello', case when first = '' then 'שלום,' else 'שלום ' || first || ',' end,
    'meeting_block', mb, 'credit_block', cb, 'me_link', 'https://harpatka.co.il/me/', 'wa_hadar', 'https://wa.me/972546163012', 'wa_ofir', 'https://wa.me/972587078708');
end $f$;
revoke all on function __S__.harpatka_mail_common(uuid, uuid) from public, anon, authenticated;

-- שולח למשתתף, או מתעד שלא נשלח כי אין לו אימייל
create or replace function __S__.harpatka_mail_participant(p_key text, p_pid uuid, p_vars jsonb)
returns void language plpgsql security definer set search_path = __S__, public as $f$
declare em text;
begin
  select lower(m.email) into em from __S__.harpatka_members m where m.participant_id = p_pid and coalesce(m.email, '') <> '' and m.status <> 'blocked' order by (m.status = 'approved') desc limit 1;
  if em is null then
    perform __S__.harpatka_mail_record(p_key, p_vars, null, null, null, 'failed', 'אין אימייל, המשתתף לא מחובר לחשבון גוגל');
  else
    perform __S__.harpatka_send_mail(p_key, p_vars, em);
  end if;
end $f$;
revoke all on function __S__.harpatka_mail_participant(text, uuid, jsonb) from public, anon, authenticated;

create or replace function __S__.harpatka_refund_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare mname text;
begin
  if new.kind <> 'refund' or coalesce(new.amount, 0) <= 0 then return null; end if;
  select pm.name into mname from __S__.harpatka_pay_methods pm where pm.key = new.method;
  perform __S__.harpatka_mail_participant('payment_refunded', new.participant_id, __S__.harpatka_mail_common(new.participant_id, new.meeting_id)
    || jsonb_build_object('amount', '₪' || trim_scale(new.amount)::text, 'how', case when coalesce(mname, '') = '' then '' else ' ב' || mname end));
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את ההחזר
end $f$;
revoke all on function __S__.harpatka_refund_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_refund_mail on __S__.harpatka_payments;
create constraint trigger harpatka_refund_mail after insert on __S__.harpatka_payments deferrable initially deferred for each row execute function __S__.harpatka_refund_mail_fn();

create or replace function __S__.harpatka_removed_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare mt __S__.harpatka_meetings;
begin
  select * into mt from __S__.harpatka_meetings where id = old.meeting_id;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return null; end if;   -- מפגש שעבר: ניקוי של מנהל, לא הודעה למשתתף
  if not exists (select 1 from __S__.harpatka_participants p where p.id = old.participant_id) then return null; end if;
  perform __S__.harpatka_mail_participant('meeting_removed', old.participant_id, __S__.harpatka_mail_common(old.participant_id, old.meeting_id));
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את ההסרה
end $f$;
revoke all on function __S__.harpatka_removed_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_removed_mail on __S__.harpatka_attendance;
create constraint trigger harpatka_removed_mail after delete on __S__.harpatka_attendance deferrable initially deferred for each row execute function __S__.harpatka_removed_mail_fn();
notify pgrst, 'reload schema';
