-- העדפות תצוגה ברמת המשתמש (מנהל): תגיות, תשלום, שליחת פרטי הערב והגעה לערב (תפריט "תצוגה" בדף הניהול).
-- תגיות ותשלום: true/false (ברירת מחדל מוצג). שליחה והגעה: null = אוטומטי לפי התזמונים, true = תמיד מוצג, false = מוסתר.
alter table public.harpatka_admin_prefs add column if not exists view_tags boolean;
alter table public.harpatka_admin_prefs add column if not exists view_pay boolean;
alter table public.harpatka_admin_prefs add column if not exists view_sent boolean;
alter table public.harpatka_admin_prefs add column if not exists view_att boolean;
alter table test.harpatka_admin_prefs add column if not exists view_tags boolean;
alter table test.harpatka_admin_prefs add column if not exists view_pay boolean;
alter table test.harpatka_admin_prefs add column if not exists view_sent boolean;
alter table test.harpatka_admin_prefs add column if not exists view_att boolean;
notify pgrst, 'reload schema';
