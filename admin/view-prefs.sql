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

-- תצוגה לפי מפגש: העדפות התצוגה נשמרות לכל מנהל בנפרד לכל מפגש ולתמונת המצב הכללית ("all"): {"all": {...}, "<מזהה מפגש>": {"tags": bool, "pay": bool, "sent": bool|null, "att": bool|null}}
alter table public.harpatka_admin_prefs add column if not exists view_scopes jsonb;
alter table test.harpatka_admin_prefs add column if not exists view_scopes jsonb;
notify pgrst, 'reload schema';
