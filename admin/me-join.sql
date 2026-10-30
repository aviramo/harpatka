-- ==========================================================================
-- הרשמה עם חשבון גוגל בצעד אחד (30.10.26): מי שהתחבר עם גוגל ואין לחשבון שלו משתתף מקושר ממלא את הפרטים בפופאפ ההרשמה,
-- והלחיצה על "הרשמה" יוצרת משתתף, מחברת אליו את חשבון הגוגל (מאושר מיד) ורושמת למפגש באותו צעד.
-- p_meeting: המפגש שנבחר (בלי: המפגש הקרוב, כמו harpatka_signup; בלי מפגש עתידי: השארת פרטים בלבד).
-- p_no_meeting = true: בלי שיוך למפגש בכלל (השלמת פרטים מהאזור האישי).
-- טלפון שכבר שייך למשתתף אחר (גם לא פעיל): ההרשמה לא מתבצעת (phone_taken), ונשלח מייל למנהלים (phone_conflict) עם הפרטים שהוזנו והאימייל של החשבון.
-- מחזירה: created, או invalid_* / blocked / phone_taken.
-- נכתב ל-public; בסביבת הבדיקות מורץ אחרי החלפת public.harpatka_ ב-test.harpatka_ (וה-search_path ל-test, public), והטמפלט נכנס ל-test.harpatka_mail_templates.
-- ==========================================================================

-- מייל למנהלים: ניסיון הרשמה מחשבון גוגל עם טלפון ששייך למשתתף קיים (אותה תבנית כמו "הרשמה חדשה מהאתר", עם האימייל של החשבון)
insert into public.harpatka_mail_templates (key, subject, html) values ('phone_conflict', 'התחברות עם טלפון שכבר קיים: {{name}}',
'<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#C96F52;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div><div style="font-size:22px;font-weight:bold;margin-top:4px">התחברות עם טלפון שכבר קיים</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:26px;font-weight:bold;color:#3F382F;margin-bottom:6px">{{name}}</div>
<div style="font-size:15px;color:#8A7F72;margin-bottom:14px">חשבון גוגל ניסה להירשם עם מספר טלפון ששייך למשתתף אחר. ההרשמה לא בוצעה</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">אימייל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold" dir="ltr" align="right">{{email}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">טלפון</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold" dir="ltr" align="right">{{phone}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">הטלפון שייך ל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{existing_name}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">גיל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{age}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מגדר</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{gender}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מפגש</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{meeting}}</td></tr>
</table>
<a href="{{wa_link}}" style="display:block;background:#25A55F;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">שליחת וואטסאפ</a>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">המשתתף הקיים בדף הניהול</a>
</div></div></div>')
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

create or replace function public.harpatka_notify_phone_conflict(p_name text, p_phone text, p_age int, p_gender text, p_email text, p_mid uuid, p_existing uuid, p_no_meeting boolean default false)
returns void language plpgsql security definer set search_path to 'public' as $$
declare md date; mt time; meeting text; ename text; ph text := coalesce(p_phone, '');
begin
  if p_mid is not null then select meeting_date, meeting_time into md, mt from public.harpatka_meetings where id = p_mid; end if;
  meeting := case when coalesce(p_no_meeting, false) then 'בלי מפגש (השלמת פרטים באזור האישי)'
                  when md is null then 'לא נבחר מפגש' else to_char(md, 'DD.MM.YYYY') || coalesce(' · ' || to_char(mt, 'HH24:MI'), '') end;
  select name into ename from public.harpatka_participants where id = p_existing;
  perform public.harpatka_send_mail('phone_conflict',
    jsonb_build_object('name', p_name, 'phone', case when ph like '+972%' then '0' || substr(ph, 5) else ph end, 'age', p_age,
      'gender', case p_gender when 'male' then 'גבר' when 'female' then 'אישה' else 'לא צוין' end,
      'email', coalesce(p_email, ''), 'meeting', meeting, 'existing_name', coalesce(ename, ''),
      'wa_link', 'https://wa.me/' || regexp_replace(ph, '\D', '', 'g'),
      'admin_link', 'https://harpatka.co.il/admin/?p=' || p_existing));
exception when others then null;
end $$;
revoke all on function public.harpatka_notify_phone_conflict(text, text, int, text, text, uuid, uuid, boolean) from public;

create or replace function public.harpatka_me_join(p_first text, p_last text, p_age int, p_gender text, p_phone text,
  p_meeting uuid default null, p_src text default null, p_no_meeting boolean default false)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  fn text := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g'));
  ln text := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
  m public.harpatka_members; pid uuid; res text;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if found and m.status = 'blocked' then return 'blocked'; end if;
  if char_length(fn) < 2 or char_length(ln) < 2 or char_length(fn) > 40 or char_length(ln) > 40 then return 'invalid_name'; end if;
  if coalesce(norm, '') = '' then return 'invalid_phone'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is null or p_gender not in ('male', 'female') then return 'invalid_gender'; end if;

  -- טלפון ששייך למשתתף קיים (גם לא פעיל): לא נרשמים ולא מחברים, ומודיעים למנהלים
  select id into pid from public.harpatka_participants where phone_norm = norm order by active desc, created_at limit 1;
  if pid is not null then
    perform public.harpatka_notify_phone_conflict(btrim(fn || ' ' || ln), norm, p_age, p_gender, lower(coalesce(auth.jwt() ->> 'email', '')),
      case when coalesce(p_no_meeting, false) then null else p_meeting end, pid, p_no_meeting);
    return 'phone_taken';
  end if;

  if coalesce(p_no_meeting, false) then
    -- בלי שיוך למפגש: משתתף חדש עם הערת מערכת אחת ומייל הרשמה חדשה למנהלים
    perform set_config('harpatka.skip_note', '1', true);
    insert into public.harpatka_participants (first_name, last_name, phone, phone_norm, age, age_set_at, source, gender)
      values (fn, ln, norm, norm, p_age, current_date, case when p_src = 'p' then 'site-ad' else 'site' end, p_gender)
      returning id into pid;
    perform public.harpatka_sys_note(pid, 'נרשם/ה דרך האזור האישי (בלי שיוך למפגש) · טלפון ' || norm, 'registered', null, null, null, null, case when p_src = 'p' then 'site-ad' else 'site' end);
    perform public.harpatka_notify_signup(btrim(fn || ' ' || ln), norm, p_age, null, null, pid, null, p_gender);
    res := 'created';
  else
    -- עם מפגש: אותה הרשמה בדיוק כמו בטופס באתר (הערות מערכת, מייל למנהלים, שיוך למפגש), ואז חיבור החשבון
    res := public.harpatka_signup(p_phone, p_age, p_gender, p_src, fn, ln, null, p_meeting, null);
    if res <> 'created' then return case when res = 'exists' then 'phone_taken' else res end; end if;   -- מירוץ: הטלפון נוצר בינתיים
    select id into pid from public.harpatka_participants where phone_norm = norm order by active desc, created_at limit 1;
    if pid is null then return 'error'; end if;
  end if;

  -- חיבור חשבון הגוגל למשתתף החדש (מאושר מיד)
  select * into m from public.harpatka_members where user_id = uid;
  if found then
    update public.harpatka_members set participant_id = pid, phone_norm = norm, status = 'approved', wants_me = true where user_id = uid;
  else
    insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status, wants_me)
    values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid, 'approved', true);
  end if;
  return res;
end $$;
revoke all on function public.harpatka_me_join(text, text, int, text, text, uuid, text, boolean) from public;
grant execute on function public.harpatka_me_join(text, text, int, text, text, uuid, text, boolean) to authenticated;
