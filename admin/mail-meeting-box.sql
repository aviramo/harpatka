-- פרטי המפגש במיילים למשתתפים: רכיב אחד, באותו מבנה כמו כרטיס המפגש בדף הבית (2.11.26). מריצים אחרי mail-registered.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-meeting-box.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-meeting-box.sql | supabase db query --linked
-- * harpatka_mail_meeting_box: תמונה, שם, מועד ושורת עיר, מיקום וכמות משתתפים. כל שדה ריק במפגש נלקח מסוג המפגש.
-- * בלי שכפול: שם שזהה לכותרת המייל ("יוצאים להרפתקה") לא מוצג שוב, והמועד הוסר מהמשפט במייל דחיית התשלום.
-- * harpatka_me מחזירה גם img ו-max, וגם שם, עיר ומיקום מהסוג כשהם ריקים במפגש, לאזור האישי.
-- * הרצה חוזרת של mail-refund-removed.sql, payment-mail.sql או payment-reject.sql מחזירה את הגרסה הישנה: אחריהן מריצים שוב את הקובץ הזה.
create or replace function __S__.harpatka_mail_meeting_box(p_mid uuid)
returns text language plpgsql stable security definer set search_path = __S__, public as $f$
declare
  mt __S__.harpatka_meetings; ty __S__.harpatka_meeting_types; nm text; wh text; img text; n int;
  days text[] := array['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
begin
  select * into mt from __S__.harpatka_meetings where id = p_mid;
  if not found then return ''; end if;
  select * into ty from __S__.harpatka_meeting_types where id = mt.type_id;
  nm := coalesce(nullif(trim(mt.name), ''), trim(ty.name), '');
  if nm = 'יוצאים להרפתקה' then nm := ''; end if;   -- כבר בכותרת המייל
  img := coalesce(nullif(trim(mt.image_url), ''), nullif(trim(ty.image_url), ''), (select nullif(trim(s.value), '') from __S__.harpatka_public_settings s where s.key = 'default_meeting_image'));
  n := coalesce(mt.max_participants, ty.max_participants);
  wh := concat_ws(' · ', coalesce(nullif(trim(mt.city), ''), nullif(trim(ty.city), '')), coalesce(nullif(trim(mt.place), ''), nullif(trim(ty.place), '')), case when n > 0 then n || ' משתתפים' end);
  return '<div style="border:1px solid #FFD8AE;border-bottom:4px solid #E5562D;background:#FFFFFF;text-align:center;margin-bottom:18px">'
    || case when img is not null then '<img src="' || __S__.harpatka_pm_esc(img) || '" width="520" alt="" style="display:block;width:100%;max-width:100%;height:auto;border:0">' else '' end
    || '<div style="padding:14px 12px 16px">'
    || case when nm <> '' then '<div style="font-size:15px;font-weight:bold;color:#C8411B;margin-bottom:4px">' || __S__.harpatka_pm_esc(nm) || '</div>' else '' end
    || '<div style="font-size:24px;line-height:1.25;font-weight:bold;color:#2C231D">יום ' || days[extract(dow from mt.meeting_date)::int + 1] || ' ' || to_char(mt.meeting_date, 'FMDD.FMMM') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || '</div>'
    || case when wh <> '' then '<div style="font-size:15px;line-height:1.4;font-weight:bold;color:#4A3D33;margin-top:6px"><span style="display:inline-block;width:8px;height:8px;background:#0F8A93;margin-left:6px"></span>' || __S__.harpatka_pm_esc(wh) || '</div>' else '' end
    || '</div></div>';
end $f$;
revoke all on function __S__.harpatka_mail_meeting_box(uuid) from public, anon, authenticated;

-- התבניות: מסגרת אחת במקום הפרטים הישנים, ובלי המועד בתוך המשפט
update __S__.harpatka_mail_templates set html = regexp_replace(html, '<div[^>]*>\{\{\{name_block\}\}\}<div[^>]*>\{\{when\}\}</div>\{\{\{where_block\}\}\}</div>', '{{{meeting_block}}}')
  where key in ('payment_confirmed', 'payment_partial');
update __S__.harpatka_mail_templates set html = regexp_replace(replace(html, 'ששילמת למפגש ב-{{meeting}},', 'ששילמת למפגש,'), '(<div[^>]*>המקום שלך עדיין לא שמור)', '{{{meeting_block}}}\1')
  where key = 'payment_rejected' and position('{{{meeting_block}}}' in html) = 0;

do $do$
declare d text; old text; marker text := '__S__.harpatka_mail_meeting_box(';
begin
  -- מיילים שמשתמשים ב-meeting_block המשותף
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_mail_common';
  if position(marker in d) = 0 then
    old := d;
    d := regexp_replace(d, $r$if p_mid is not null then.*?end if;\s*end if;$r$, 'if p_mid is not null then mb := __S__.harpatka_mail_meeting_box(p_mid); end if;');
    if d = old then raise exception 'harpatka_mail_common patch did not apply'; end if;
    execute d;
  end if;
  -- מיילי התשלום
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_pay_mail';
  if position(marker in d) = 0 then
    if position($s$'name_block', name_b$s$ in d) = 0 then raise exception 'harpatka_pay_mail patch did not apply'; end if;
    execute replace(d, $s$'name_block', name_b$s$, $s$'meeting_block', __S__.harpatka_mail_meeting_box(p_mid), 'name_block', name_b$s$);
  end if;
  -- דחיית דיווח תשלום
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_att_reject_notify';
  if position(marker in d) = 0 then
    if position($s$'meeting', to_char(mt.meeting_date$s$ in d) = 0 then raise exception 'harpatka_att_reject_notify patch did not apply'; end if;
    execute replace(d, $s$'meeting', to_char(mt.meeting_date$s$, $s$'meeting_block', __S__.harpatka_mail_meeting_box(new.meeting_id), 'meeting', to_char(mt.meeting_date$s$);
  end if;
  -- האזור האישי: תמונה, כמות משתתפים ושדות שריקים במפגש מהסוג
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me';
  if position($s$'img', $s$ in d) = 0 then
    if position($s$'name', mt.name, 'city', mt.city, 'place', mt.place,$s$ in d) = 0 or position('from __S__.harpatka_meetings mt left join __S__.harpatka_attendance a on a.meeting_id = mt.id and a.participant_id = pid' in d) = 0 then raise exception 'harpatka_me patch did not apply'; end if;
    d := replace(d, $s$'name', mt.name, 'city', mt.city, 'place', mt.place,$s$,
      $s$'name', coalesce(nullif(trim(mt.name), ''), ty.name), 'city', coalesce(nullif(trim(mt.city), ''), ty.city), 'place', coalesce(nullif(trim(mt.place), ''), ty.place), 'max', coalesce(mt.max_participants, ty.max_participants),
      'img', coalesce(nullif(trim(mt.image_url), ''), nullif(trim(ty.image_url), ''), (select nullif(trim(st.value), '') from __S__.harpatka_public_settings st where st.key = 'default_meeting_image')),$s$);
    d := replace(d, 'from __S__.harpatka_meetings mt left join __S__.harpatka_attendance a on a.meeting_id = mt.id and a.participant_id = pid',
      'from __S__.harpatka_meetings mt left join __S__.harpatka_meeting_types ty on ty.id = mt.type_id left join __S__.harpatka_attendance a on a.meeting_id = mt.id and a.participant_id = pid');
    execute d;
  end if;
end $do$;
notify pgrst, 'reload schema';
