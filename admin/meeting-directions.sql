-- הוראות הגעה למפגש (כתובת וכו', טקסט חופשי בכמה שורות): נערך בחלון המפגש בדף הניהול ומוצג באזור האישי (me/).
-- להריץ על public ועל test (בתיקון הסכמה בשורות).
alter table public.harpatka_meetings add column if not exists directions text not null default '';
alter table test.harpatka_meetings add column if not exists directions text not null default '';
