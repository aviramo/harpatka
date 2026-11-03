-- תיקון (3.11.26): harpatka_me היא קריאה, ולא משנה נתונים. עד עכשיו היא החזירה לפעילות משתתף שהוסר בכל טעינה של האתר עם החשבון המחובר אליו,
-- גם ברקע (טאב פתוח, טעינה מוקדמת של האזור האישי, אות זמן אמת שיוצא מעצם המחיקה), ולכן "מחיקת משתתף" התבטלה אחרי שנייה.
-- עכשיו: משתתף שהוסר ממשיך לראות את האזור האישי ואת המפגשים שלו, ונשאר מחוק, וחוזר לפעילות רק כשהוא עצמו נרשם למפגש (או כשמנהל מחזיר אותו).
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/me-read-only.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/me-read-only.sql | supabase db query --linked
do $do$
declare d text; s int; e int; k text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_me';
  if d like '%חזר/ה לפעילות דרך האזור האישי%' then
    s := position('-- משתתף שהוסר' in d);
    if s = 0 then s := position('if p_as is null and exists (select 1 from __S__.harpatka_participants where id = pid and not active) then' in d); end if;
    k := 'select * into pa from __S__.harpatka_participants where id = pid and active;';
    e := position(k in d);
    if s = 0 or e = 0 or e < s then raise exception 'harpatka_me: לא נמצא'; end if;
    d := left(d, s - 1) || '-- קריאה בלבד: משתתף שהוסר רואה את האזור האישי ונשאר מחוק; חוזר לפעילות רק כשהוא נרשם למפגש' || E'\n  select * into pa from __S__.harpatka_participants where id = pid;' || substr(d, e + length(k));
    execute d;
  end if;

  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_me_register';
  if d not like '%set active = true%' then
    k := 'insert into __S__.harpatka_attendance (participant_id, meeting_id, paid) values (pid, p_meeting, false);';
    if position(k in d) = 0 then raise exception 'harpatka_me_register: לא נמצא'; end if;
    d := replace(d, k, 'update __S__.harpatka_participants set active = true where id = pid and not active;   -- מי שהוסר ונרשם בעצמו למפגש חוזר לפעילות' || E'\n  ' || k);
    execute d;
  end if;
end $do$;
