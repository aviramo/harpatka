-- מייל למשתתף כשמפגש מסומן "לא לתשלום" (2.11.26). מריצים אחרי mail-refund-removed.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-no-pay.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-no-pay.sql | supabase db query --linked
-- * לא שולם כלום, ולכן לא "התשלום התקבל" אלא "המקום שלך שמור", עם פרטי המפגש והוראות ההגעה. לא במפגש שכבר עבר. נקשר להערה "לתשלום ← לא לתשלום".
-- * כל סימון שולח מייל: סימון, ביטול וסימון נוסף הם שני מיילים.
insert into __S__.harpatka_mail_templates (key, subject, html) values ('place_saved', 'המקום שלך שמור', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">{{hello}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">המקום שלך במפגש שמור, ולא נדרש ממך תשלום.</div>
{{{meeting_block}}}{{{credit_block}}}{{{dir_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">נתראה, אופיר והדר</div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

-- הוראות ההגעה למייל: טקסט מוגן, שורות, וקישור לתמונה או לסרטון כ"לפתיחה". רכיב אחד גם למייל התשלום
create or replace function __S__.harpatka_mail_directions(p_mid uuid)
returns text language plpgsql security definer set search_path = __S__, public as $f$
declare dirs text; dh text;
begin
  select trim(replace(coalesce(m.directions, ''), chr(13), '')) into dirs from __S__.harpatka_meetings m where m.id = p_mid;
  if coalesce(dirs, '') = '' then return ''; end if;
  dh := replace(__S__.harpatka_pm_esc(dirs), chr(10), '<br>');
  dh := regexp_replace(dh, '(https?://[^\s<]+/storage/v1/object/public/meeting-media/[^\s<]+)', '<a href="\1" style="color:#C8411B;font-weight:bold">לפתיחה</a>', 'g');
  dh := regexp_replace(dh, '(^|\s|>)(https?://[^\s<]+)', '\1<a href="\2" style="color:#C8411B;font-weight:bold">\2</a>', 'g');
  return '<div style="font-size:16px;font-weight:bold;margin-bottom:6px">איך מגיעים</div><div style="font-size:16px;line-height:1.6;margin-bottom:18px">' || dh || '</div>';
end $f$;
revoke all on function __S__.harpatka_mail_directions(uuid) from public, anon, authenticated;

do $do$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_pay_mail';
  if d not like '%harpatka_mail_directions%' then
    d := regexp_replace(d, $r$dirs := trim\(replace\(coalesce\(mt\.directions.*?dir_b := [^\n]*\s+end if;$r$, 'dir_b := __S__.harpatka_mail_directions(p_mid);');
    if d not like '%harpatka_mail_directions%' then raise exception 'harpatka_pay_mail patch did not apply'; end if;
    execute d;
  end if;
end $do$;

create or replace function __S__.harpatka_no_pay_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare mt __S__.harpatka_meetings;
begin
  if not coalesce(new.no_pay, false) or coalesce(old.no_pay, false) then return null; end if;
  select * into mt from __S__.harpatka_meetings where id = new.meeting_id;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return null; end if;   -- מפגש שעבר: בלי מייל
  perform __S__.harpatka_mail_participant('place_saved', new.participant_id, __S__.harpatka_mail_common(new.participant_id, new.meeting_id)
    || jsonb_build_object('dir_block', __S__.harpatka_mail_directions(new.meeting_id)));
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את הסימון
end $f$;
revoke all on function __S__.harpatka_no_pay_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_no_pay_mail on __S__.harpatka_attendance;
create constraint trigger harpatka_no_pay_mail after update of no_pay on __S__.harpatka_attendance deferrable initially deferred for each row execute function __S__.harpatka_no_pay_mail_fn();
notify pgrst, 'reload schema';
