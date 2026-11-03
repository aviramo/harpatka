-- מיילים למנהלים על הרשמות: רק על משתתפים חדשים (3.11.26, לבקשת בעל האתר). אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-new-only.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-new-only.sql | supabase db query --linked
-- נשאר: "הרשמה חדשה מהאתר" (harpatka_notify_signup) על מי שנוצר עכשיו: בטופס מיד, ובהרשמה עם גוגל כשהשלים את הפרטים.
-- נפסק: "הרשמה למפגש" של משתתף קיים (הטריגר נמחק; התבנית meeting_signup נשארה בלי שימוש), מי שהוסר וחזר, ומשתתף ותיק שהשלים פרטים חסרים.
-- להחזרת "הרשמה למפגש": להריץ שוב את admin/meeting-reg-mail.sql.

drop trigger if exists harpatka_att_reg_mail on __S__.harpatka_attendance;

do $do$
declare d text; a text;
begin
  -- השלמת פרטים: מייל רק למי שנוצר עם טלפון בלבד (עוד בלי שם). מי שכבר היה לו שם הוא משתתף ותיק
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_participant_completed';
  if d not like '%ותיק%' then
    a := '  if __S__.harpatka_details_done(old.first_name, old.last_name, old.age, old.gender) or not';
    if position(a in d) = 0 then raise exception 'harpatka_participant_completed: לא נמצא'; end if;
    d := replace(d, a, '  if btrim(coalesce(old.first_name, '''')) <> '''' then return new; end if;   -- היה לו שם: משתתף ותיק שהשלים פרטים חסרים, לא משתתף חדש' || E'\n' || a);
    execute d;
  end if;

  -- טופס ההרשמה: מי שהוסר וחזר לא נחשב משתתף חדש למייל
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_signup';
  if d not like '%and not react and not found%' then
    a := 'if res = ''created'' and not found then';
    if position(a in d) = 0 then raise exception 'harpatka_signup: לא נמצא'; end if;
    d := replace(d, a, 'if res = ''created'' and not react and not found then');
    execute d;
  end if;

  -- הרשמה עם גוגל: אותו דבר
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_me_phone';
  if d like '%if react then select * into pa%' then
    d := regexp_replace(d, 'if react then select \* into pa from .*?harpatka_notify_signup\(.*?end if; end if;', '', 'n');
    if d like '%if react then select * into pa%' then raise exception 'harpatka_me_phone: לא הוסר'; end if;
    execute d;
  end if;
end $do$;
