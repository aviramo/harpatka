-- סטטוסי מפגש "לפני" ו"אחרי" המפגש (27.10.26): עמודת phase בטבלת הסטטוסים, והסטטוס "יצא באמצע" ברשימת "אחרי המפגש".
-- אידמפוטנטי; להריץ על public, ובנוסף על test (אחרי החלפת public ב-test), בלי נתונים.
alter table public.harpatka_statuses add column if not exists phase text not null default 'before';
insert into public.harpatka_statuses (key, label, color, sort, scope, phase)
values ('m_left', 'יצא באמצע', 'neutral', 1, 'meeting', 'after')
on conflict (key) do nothing;
notify pgrst, 'reload schema';

-- שני סטטוסים לכל שיוך משתתף-מפגש: לפני המפגש (status_key והדגלים) ואחרי המפגש (after_key, מפתח מתוך הסטטוסים עם phase = 'after').
alter table public.harpatka_attendance add column if not exists after_key text;
