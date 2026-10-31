-- אי אפשר למחוק מפגש שמשויכים אליו משתתפים (31.10.26): גם בבסיס הנתונים, לא רק בדף הניהול.
-- קודם השיוכים נמחקו יחד עם המפגש (on delete cascade); עכשיו המחיקה נכשלת כל עוד יש שיוך (on delete restrict).
-- סוג מפגש כבר מוגן (harpatka_meetings.type_id on delete restrict): אפשר למחוק סוג רק אחרי שהמפגשים שלו נמחקו, ומפגש עם משתתפים לא נמחק.
-- אידמפוטנטי. בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_.

alter table public.harpatka_attendance drop constraint if exists harpatka_attendance_meeting_id_fkey;
alter table public.harpatka_attendance add constraint harpatka_attendance_meeting_id_fkey
  foreign key (meeting_id) references public.harpatka_meetings(id) on delete restrict;

notify pgrst, 'reload schema';
