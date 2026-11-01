-- תגיות משתתפים ברמת סוג מפגש (1.11.26): כל תגית שייכת לסוג מפגש (harpatka_statuses.type_id), כמו הסטטוסים.
-- תגיות קיימות בלי סוג עוברות לסוג הראשון (הקוד גם כך מתייחס ל-type_id ריק כסוג הראשון, ולכן ההרצה לא חובה לתפקוד).
-- אידמפוטנטי. בבדיקות: מריצים עם public -> test.
update public.harpatka_statuses
   set type_id = (select id from public.harpatka_meeting_types order by sort, created_at limit 1)
 where scope = 'participant' and type_id is null;
