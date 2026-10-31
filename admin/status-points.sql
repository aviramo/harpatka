-- ציון התמדה לסטטוס (31.10.26): מספר שלם מ-5- עד 5 לכל סטטוס "במפגש" ו"אחרי המפגש"; סכום הציונים של המשתתף במפגש נכנס לחישוב ההתמדה.
-- סטטוסים של "לפני המפגש" לא משתמשים בו (נשאר 0). ברירת מחדל: "הגיע" +1, "יצא" -1 (הגיע ויצא = 0 למפגש).
-- אידמפוטנטי. להריץ על public ועל test (החלפת __S__):  sed 's/__S__/public/g' admin/status-points.sql | supabase db query --linked   (וגם עם test)
alter table __S__.harpatka_statuses add column if not exists points integer not null default 0;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'harpatka_statuses_points_range' and conrelid = '__S__.harpatka_statuses'::regclass) then
    alter table __S__.harpatka_statuses add constraint harpatka_statuses_points_range check (points between -5 and 5);
  end if;
end $c$;
update __S__.harpatka_statuses set points = 1 where key = 'arrived' and points = 0;
update __S__.harpatka_statuses set points = -1 where key = 'm_left' and points = 0;
notify pgrst, 'reload schema';
