-- מייל למשתתף על ההרשמה למפגש: נרשמת, ונשאר לשלם (2.11.26). מריצים אחרי mail-log.sql ו-signup-after-details.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-registered.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-registered.sql | supabase db query --linked
-- * נשלח רק כשיש פרטים אישיים: בהרשמה עצמה אם כבר יש, ואחרת ברגע שהמשתתף משלים אותם (ואז נקשר להערת ההשלמה). מי שעצר אחרי הטלפון לא מקבל מייל.
-- * לא כשמנהל פועל על משתתף אחר (חוץ משיוך מחדש אחרי הסרה, mail-relink.sql), לא במפגש שעבר, לא ב"לא לתשלום" ולא כשכבר שולם. פעם אחת לכל רישום.
-- * טריגרים דחויים: רצים בסוף הפעולה. בלי חשבון גוגל: "המייל לא נשלח" בהערה, כמו בכל מייל.
-- * harpatka_me_phone: קודם מחברים את החשבון למשתתף, ורק אחר כך נרשמים למפגש.
insert into __S__.harpatka_mail_templates (key, subject, html) values ('meeting_registered', 'נרשמת למפגש, נשאר לשלם', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">{{hello}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">נרשמת למפגש:</div>
{{{meeting_block}}}
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">המקום נשמר זמנית, והוא יישמר קבוע רק אחרי התשלום.{{{price_note}}}</div>
{{{credit_block}}}
<a href="{{me_link}}" style="display:block;background:#4E7D2C;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">{{pay_label}}</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;text-align:center;margin-top:10px">ברגע שנקבל את התשלום,<br>{{pay_after}}</div>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">נתראה, אופיר והדר</div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

-- שולח פעם אחת לכל רישום: לא במפגש שעבר, לא ב"לא לתשלום" ולא כשכבר שולם. p_ev: ההערה שאליה המייל נקשר, כשהוא נשלח בגלל אירוע אחר
create or replace function __S__.harpatka_reg_mail_send(p_pid uuid, p_mid uuid, p_ev text default null)
returns void language plpgsql security definer set search_path = __S__, public as $f$
declare
  a __S__.harpatka_attendance; mt __S__.harpatka_meetings; v jsonb; price int; nx jsonb; lft int;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  note text := '';
begin
  select * into a from __S__.harpatka_attendance where participant_id = p_pid and meeting_id = p_mid;
  if not found or coalesce(a.no_pay, false) then return; end if;
  select * into mt from __S__.harpatka_meetings where id = p_mid;
  if not found or mt.meeting_date < today then return; end if;
  if exists (select 1 from __S__.harpatka_payments x where x.participant_id = p_pid and x.meeting_id = p_mid and x.kind = 'payment') then return; end if;
  if exists (select 1 from __S__.harpatka_mail_log l where l.participant_id = p_pid and l.meeting_id = p_mid and l.tpl = 'meeting_registered' and l.sent_at >= a.created_at) then return; end if;
  lft := mt.meeting_date - today;
  price := __S__.harpatka_meeting_price(mt.price_tiers, lft);
  -- המדרגה הבאה, כדי שהסכום במייל לא יטעה כשהמחיר עולה
  select e into nx from jsonb_array_elements(case when jsonb_typeof(mt.price_tiers -> 'steps') = 'array' then mt.price_tiers -> 'steps' else '[]'::jsonb end) e
    where (e ->> 'days')::int < lft order by (e ->> 'days')::int desc limit 1;
  if nx is not null and (nx ->> 'price')::int > coalesce(price, 0) then
    note := ' המחיר עולה ל-₪' || (nx ->> 'price') || ' ב-' || to_char(mt.meeting_date - (nx ->> 'days')::int, 'FMDD.FMMM') || '.';
  end if;
  v := __S__.harpatka_mail_common(p_pid, p_mid);
  if p_ev is not null then v := v || jsonb_build_object('_ev', p_ev); end if;
  perform __S__.harpatka_mail_participant('meeting_registered', p_pid, v || jsonb_build_object(
    'me_link', 'https://harpatka.co.il/me/?m=' || p_mid,
    'pay_label', case when price is null then 'לתשלום' else 'לתשלום ₪' || price end,
    'pay_after', 'נשלח לך מייל אישור' || case when coalesce(__S__.harpatka_mail_directions(p_mid), '') <> '' then ' עם הוראות ההגעה' else '' end,   -- מבטיחים הוראות הגעה רק כשיש כאלה למפגש
    'price_note', note));
end $f$;
revoke all on function __S__.harpatka_reg_mail_send(uuid, uuid, text) from public, anon, authenticated;

-- מנהל שפועל על משתתף אחר (דף הניהול או צפייה כמשתתף): בלי מייל
create or replace function __S__.harpatka_reg_mail_by_admin(p_pid uuid) returns boolean
language sql stable security definer set search_path = __S__, public as $f$
  select lower(coalesce(auth.jwt() ->> 'email', '')) <> ''
    and exists (select 1 from public.harpatka_admins a where lower(a.email) = lower(auth.jwt() ->> 'email'))
    and not exists (select 1 from __S__.harpatka_members x where x.user_id = auth.uid() and x.participant_id = p_pid)
$f$;
revoke all on function __S__.harpatka_reg_mail_by_admin(uuid) from public, anon, authenticated;

-- הרשמה: כשכבר יש פרטים. בלי פרטים המייל מחכה להשלמה
create or replace function __S__.harpatka_reg_user_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare pa __S__.harpatka_participants;
begin
  if __S__.harpatka_reg_mail_by_admin(new.participant_id)
     and not exists (select 1 from __S__.harpatka_notes n where n.participant_id = new.participant_id and n.meeting_id = new.meeting_id and n.event_type = 'meeting_removed') then
    return null;
  end if;
  select * into pa from __S__.harpatka_participants where id = new.participant_id;
  if not found or not __S__.harpatka_details_done(pa.first_name, pa.last_name, pa.age, pa.gender) then return null; end if;
  perform __S__.harpatka_reg_mail_send(new.participant_id, new.meeting_id);
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את ההרשמה
end $f$;
revoke all on function __S__.harpatka_reg_user_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_reg_user_mail on __S__.harpatka_attendance;
create constraint trigger harpatka_reg_user_mail after insert on __S__.harpatka_attendance deferrable initially deferred for each row execute function __S__.harpatka_reg_user_mail_fn();

-- השלמת פרטים: מייל על המפגשים העתידיים שהמשתתף כבר רשום אליהם
create or replace function __S__.harpatka_reg_details_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare r record;
begin
  if __S__.harpatka_details_done(old.first_name, old.last_name, old.age, old.gender) or not __S__.harpatka_details_done(new.first_name, new.last_name, new.age, new.gender) then return null; end if;
  if __S__.harpatka_reg_mail_by_admin(new.id) then return null; end if;
  for r in select a.meeting_id from __S__.harpatka_attendance a where a.participant_id = new.id order by a.created_at loop
    perform __S__.harpatka_reg_mail_send(new.id, r.meeting_id, 'profile_completed');
  end loop;
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את השמירה
end $f$;
revoke all on function __S__.harpatka_reg_details_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_reg_details_mail on __S__.harpatka_participants;
create constraint trigger harpatka_reg_details_mail after update of first_name, last_name, age, gender on __S__.harpatka_participants deferrable initially deferred for each row execute function __S__.harpatka_reg_details_mail_fn();

-- harpatka_me_phone: חיבור החשבון לפני ההרשמה
do $do$
declare d text; a int; b int; c int; blk text; mark text := E'  -- ההרשמה למפגש כבר עכשיו';
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me_phone';
  if d is null then raise exception 'harpatka_me_phone not found'; end if;
  a := position(E'  -- חיבור חשבון הגוגל למשתתף' in d);
  c := position(mark in d);
  if a = 0 or c = 0 then raise exception 'harpatka_me_phone markers not found'; end if;
  if a > c then   -- עוד לא הוחל
    b := position(E'  select * into pa from __S__.harpatka_participants where id = pid;\n  return jsonb_build_object(' in d);
    if b = 0 or b < a then raise exception 'harpatka_me_phone end marker not found'; end if;
    blk := substr(d, a, b - a);
    d := substr(d, 1, a - 1) || substr(d, b);
    d := substr(d, 1, c - 1) || blk || substr(d, c);
    execute d;
  end if;
end $do$;
notify pgrst, 'reload schema';
