-- 31.10.26: בנוסח ההודעה לפני המפגש המשתנה {מיקום} נקרא עכשיו {הוראות הגעה} (מוחלף בהוראות ההגעה של המפגש).
-- הקוד עדיין מבין גם {מיקום}; כאן רק מעדכנים את הנוסחים השמורים לשם החדש. אידמפוטנטי.
update public.harpatka_meeting_types set event_msg = replace(event_msg, '{מיקום}', '{הוראות הגעה}') where event_msg like '%{מיקום}%';
update public.harpatka_admin_prefs set event_msg = replace(event_msg, '{מיקום}', '{הוראות הגעה}') where event_msg like '%{מיקום}%';
