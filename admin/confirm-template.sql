-- "אישור מקום" (5.11.26): הודעת ברירת מחדל של המערכת, גלובלית לכל סוגי המפגשים, שאפשר לערוך. היא משמשת:
--   1. את המייל "התשלום התקבל" / "המקום שלך שמור" (גוף המייל נבנה מהנוסח שלה, בתוך המעטפת הרגילה של המייל);
--   2. את הוואטסאפ, כשהמייל לא יכול לצאת (למשתתף אין חשבון גוגל מחובר): דף הניהול שואל אם לשלוח את אותו תוכן בוואטסאפ;
--   3. תפריט הוואטסאפ של הרשימה (שליחה ידנית), כמו כל תבנית אחרת.
-- היא שורה בטבלת תבניות ההודעה בלי סוג ובלי מפגש, עם system_key = 'confirm' (השם קבוע; הנוסח ניתן לעריכה; default_body = נוסח ברירת המחדל לשחזור).
-- שדות חדשים בנוסח: {פרטי המפגש} (שם, תאריך ושעה, מקום; במייל: המסגרת של המפגש), {תשלום} (התשלום התקבל, או לא נדרש תשלום), {איך מגיעים} (הוראות ההגעה עם כותרת; ריק אם אין).
-- מריצים אחרי msg-templates.sql ואחרי mail-no-pay.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/confirm-template.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/confirm-template.sql | supabase db query --linked

alter table __S__.harpatka_msg_templates add column if not exists system_key text;
alter table __S__.harpatka_msg_templates add column if not exists default_body text;
create unique index if not exists harpatka_msg_templates_system on __S__.harpatka_msg_templates (system_key) where system_key is not null;
alter table __S__.harpatka_msg_templates drop constraint if exists harpatka_msg_templates_check;
alter table __S__.harpatka_msg_templates add constraint harpatka_msg_templates_check check (
  (system_key is not null and type_id is null and meeting_id is null) or (system_key is null and (type_id is null) <> (meeting_id is null)));

insert into __S__.harpatka_msg_templates (name, body, default_body, sort, system_key)
values ('אישור מקום', E'שלום {שם} 🙂\n{תשלום}\n\n{פרטי המפגש}\n\n{איך מגיעים}\n\nנתראה,\nאופיר והדר', E'שלום {שם} 🙂\n{תשלום}\n\n{פרטי המפגש}\n\n{איך מגיעים}\n\nנתראה,\nאופיר והדר', -1, 'confirm')
on conflict (system_key) where system_key is not null do update set default_body = excluded.default_body;

-- טקסט למייל: מוגן, קישור לתמונה או סרטון שצורפו (במדיה של המפגשים) כ"לפתיחה", וקישורים אחרים כקישור; שורות חדשות כ-<br>
create or replace function __S__.harpatka_html_text(p_text text)
returns text language sql immutable set search_path = __S__, public as $f$
  select replace(
    regexp_replace(
      regexp_replace(__S__.harpatka_pm_esc(coalesce(p_text, '')), '(https?://[^\s<]+/storage/v1/object/public/meeting-media/[^\s<]+)', '<a href="\1" style="color:#C8411B;font-weight:bold">לפתיחה</a>', 'g'),
      '(^|\s|>)(https?://[^\s<]+)', '\1<a href="\2" style="color:#C8411B;font-weight:bold">\2</a>', 'g'),
    chr(10), '<br>')
$f$;

-- הנוסח של "אישור מקום" אחרי מילוי השדות. p_html = false: טקסט פשוט (וואטסאפ); true: HTML לגוף המייל (פסקאות, המסגרת של המפגש, הוראות ההגעה עם הקישורים)
create or replace function __S__.harpatka_confirm_text(p_pid uuid, p_mid uuid, p_html boolean default false)
returns text language plpgsql security definer set search_path = __S__, public as $f$
declare
  body text; mt __S__.harpatka_meetings; pa __S__.harpatka_participants; l __S__.harpatka_attendance;
  days text[] := array['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  nm text; first text; dt text; whn text; wh text; dirs text; st int; hmc text := ''; hms text := ''; hme text := '';
  paytxt text := ''; parts text[] := '{}'; cr numeric; bal numeric; r record; box_plain text; dir_plain text := '';
  t text; paras text[]; para text; out text := ''; h text; wrap text := '<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">';
begin
  select b.body into body from __S__.harpatka_msg_templates b where b.system_key = 'confirm';
  body := replace(coalesce(nullif(btrim(coalesce(body, '')), ''), E'שלום {שם} 🙂\n{תשלום}\n\n{פרטי המפגש}\n\n{איך מגיעים}\n\nנתראה,\nאופיר והדר'), chr(13), '');
  select * into mt from __S__.harpatka_meetings where id = p_mid; if not found then return ''; end if;
  select * into pa from __S__.harpatka_participants where id = p_pid;
  select * into l from __S__.harpatka_attendance where participant_id = p_pid and meeting_id = p_mid;
  first := coalesce(nullif(trim(pa.first_name), ''), nullif(split_part(trim(coalesce(pa.name, '')), ' ', 1), ''), '');
  nm := coalesce(nullif(trim(mt.name), ''), (select nullif(trim(t2.name), '') from __S__.harpatka_meeting_types t2 where t2.id = mt.type_id), '');
  dt := 'יום ' || days[extract(dow from mt.meeting_date)::int + 1] || ' ' || to_char(mt.meeting_date, 'FMDD.FMMM');
  whn := dt || coalesce(' · ' || to_char(mt.meeting_time, 'HH24:MI'), '');
  wh := concat_ws(' · ', nullif(trim(mt.city), ''), nullif(trim(mt.place), ''));
  dirs := trim(replace(coalesce(mt.directions, ''), chr(13), ''));
  if mt.meeting_time is not null then
    st := extract(hour from mt.meeting_time)::int * 60 + extract(minute from mt.meeting_time)::int;
    hmc := lpad((((st - 15 + 1440) % 1440) / 60)::text, 2, '0') || ':' || lpad((((st - 15 + 1440) % 1440) % 60)::text, 2, '0');
    hms := lpad((st / 60)::text, 2, '0') || ':' || lpad((st % 60)::text, 2, '0');
    hme := lpad((((st + 120) % 1440) / 60)::text, 2, '0') || ':' || lpad((((st + 120) % 1440) % 60)::text, 2, '0');
  end if;
  -- התשלום: לא לתשלום, או מה שהוקצה למפגש (מהקרדיט ולפי דרך תשלום); בלי הקצאה עדיין: ריק
  if coalesce(l.no_pay, false) then
    paytxt := 'המקום שלך במפגש שמור, ולא נדרש ממך תשלום.';
  else
    select coalesce(sum(case when p.from_credit then p.amount else 0 end), 0) into cr from __S__.harpatka_payments p where p.participant_id = p_pid and p.meeting_id = p_mid and p.kind = 'payment';
    if cr > 0 then parts := parts || ('₪' || trim_scale(cr)::text || ' מהקרדיט'); end if;
    for r in select pm.name as mname, sum(p.amount) as amt from __S__.harpatka_payments p left join __S__.harpatka_pay_methods pm on pm.key = p.method
              where p.participant_id = p_pid and p.meeting_id = p_mid and p.kind = 'payment' and not coalesce(p.from_credit, false) group by pm.name order by pm.name loop
      parts := parts || ('₪' || trim_scale(r.amt)::text || case when coalesce(r.mname, '') = '' then '' else ' ב' || r.mname end);
    end loop;
    if coalesce(array_length(parts, 1), 0) > 0 then
      paytxt := 'התשלום התקבל, והמקום שלך במפגש נשמר.' || E'\n' || 'שולם: ' || array_to_string(parts, ' · ');
      if cr > 0 then
        select coalesce(sum(case when kind in ('credit', 'deposit') then amount when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0) into bal from __S__.harpatka_payments where participant_id = p_pid;
        if bal > 0 then paytxt := paytxt || E'\n' || 'נשאר לך קרדיט של ₪' || trim_scale(bal)::text; end if;
      end if;
    end if;
  end if;
  box_plain := concat_ws(E'\n', nullif(nm, ''), whn, nullif(wh, ''));
  if dirs <> '' then dir_plain := E'איך מגיעים\n' || dirs; end if;

  t := body;
  -- הוראות הגעה (וגם {מיקום}, השם הישן): הטקסט של המפגש; בלי הוראות השורה נמחקת
  if dirs = '' then t := regexp_replace(t, '(^|\n)[^\n]*\{(הוראות הגעה|מיקום)\}[^\n]*', '', 'g'); end if;
  t := replace(replace(t, '{הוראות הגעה}', dirs), '{מיקום}', dirs);
  t := replace(t, '{שם}', first); t := replace(t, '{תאריך}', dt); t := replace(t, '{מקום}', wh);
  t := replace(t, '{התכנסות}', hmc); t := replace(t, '{התחלה}', hms); t := replace(t, '{סיום}', hme);
  t := replace(replace(replace(t, '{פרטי המפגש}', '[[BOX]]'), '{תשלום}', '[[PAY]]'), '{איך מגיעים}', '[[DIR]]');

  if not p_html then
    t := replace(replace(replace(t, '[[BOX]]', box_plain), '[[PAY]]', paytxt), '[[DIR]]', dir_plain);
    return btrim(regexp_replace(t, '\n{3,}', E'\n\n', 'g'), E'\n ');
  end if;

  paras := regexp_split_to_array(t, '\n[ \t]*\n\s*');
  foreach para in array paras loop
    para := btrim(para, E' \n\t');
    if para = '' then continue; end if;
    if para = '[[BOX]]' then out := out || __S__.harpatka_mail_meeting_box(p_mid);
    elsif para = '[[DIR]]' then out := out || __S__.harpatka_mail_directions(p_mid);
    elsif para = '[[PAY]]' then
      if paytxt <> '' then out := out || wrap || __S__.harpatka_html_text(paytxt) || '</div>'; end if;
    else
      h := __S__.harpatka_html_text(para);
      h := replace(replace(replace(h, '[[BOX]]', __S__.harpatka_html_text(box_plain)), '[[PAY]]', __S__.harpatka_html_text(paytxt)), '[[DIR]]', __S__.harpatka_html_text(dir_plain));
      if btrim(replace(h, '<br>', '')) <> '' then out := out || wrap || h || '</div>'; end if;
    end if;
  end loop;
  return out;
end $f$;
revoke all on function __S__.harpatka_html_text(text) from public, anon, authenticated;
revoke all on function __S__.harpatka_confirm_text(uuid, uuid, boolean) from public, anon, authenticated;

-- שני מיילי הסגירה: גוף המייל מהנוסח של "אישור מקום", בתוך המעטפת הרגילה (כותרת המותג, כפתור לאזור האישי ושורת הוואטסאפ)
insert into __S__.harpatka_mail_templates (key, subject, html) values ('payment_confirmed', 'התשלום התקבל, המקום שלך שמור', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
{{{body_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <a href="{{wa}}" dir="ltr" style="color:#C8411B;font-weight:bold;white-space:nowrap">{{wa_num}}</a></div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;
insert into __S__.harpatka_mail_templates (key, subject, html) values ('place_saved', 'המקום שלך שמור', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
{{{body_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">לאזור האישי</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <a href="{{wa}}" dir="ltr" style="color:#C8411B;font-weight:bold;white-space:nowrap">{{wa_num}}</a></div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

-- תשלום שנסגר: המשתנים של המייל כוללים עכשיו body_block (הנוסח של "אישור מקום")
create or replace function __S__.harpatka_pay_mail(p_pid uuid, p_mid uuid, p_partial boolean default false, p_rem numeric default null, p_to text default null)
returns boolean language plpgsql security definer set search_path = __S__, public as $f$
declare
  em text := lower(nullif(trim(p_to), '')); mt __S__.harpatka_meetings; pa __S__.harpatka_participants; vars jsonb;
begin
  if em is null then
    select lower(m.email) into em from __S__.harpatka_members m where m.participant_id = p_pid and coalesce(m.email, '') <> '' and m.status <> 'blocked' order by (m.status = 'approved') desc limit 1;
  end if;
  select * into mt from __S__.harpatka_meetings where id = p_mid; if not found then return false; end if;
  if mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return false; end if;   -- מפגש שעבר: בלי מייל
  select * into pa from __S__.harpatka_participants where id = p_pid; if not found then return false; end if;
  vars := jsonb_build_object('_pid', p_pid, '_mid', p_mid, 'first_name', coalesce(nullif(pa.first_name, ''), pa.name, ''),
    'rem', coalesce('₪' || trim_scale(p_rem)::text, ''), 'body_block', __S__.harpatka_confirm_text(p_pid, p_mid, true),
    'me_link', 'https://harpatka.co.il/me/?m=' || p_mid) || __S__.harpatka_wa_vars();
  return __S__.harpatka_mail_close(case when p_partial then 'payment_partial' else 'payment_confirmed' end, p_pid, p_mid, vars, em);
exception when others then
  return false;   -- כשל במייל לא מבטל את התשלום
end $f$;
revoke all on function __S__.harpatka_pay_mail(uuid, uuid, boolean, numeric, text) from public, anon, authenticated;

-- מפגש שסומן "לא לתשלום": אותו גוף מייל
create or replace function __S__.harpatka_no_pay_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare mt __S__.harpatka_meetings;
begin
  if not coalesce(new.no_pay, false) or coalesce(old.no_pay, false) then return null; end if;
  select * into mt from __S__.harpatka_meetings where id = new.meeting_id;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return null; end if;   -- מפגש שעבר: בלי מייל
  perform __S__.harpatka_mail_close('place_saved', new.participant_id, new.meeting_id, __S__.harpatka_mail_common(new.participant_id, new.meeting_id)
    || jsonb_build_object('body_block', __S__.harpatka_confirm_text(new.participant_id, new.meeting_id, true)));
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את הסימון
end $f$;
revoke all on function __S__.harpatka_no_pay_mail_fn() from public, anon, authenticated;
notify pgrst, 'reload schema';
