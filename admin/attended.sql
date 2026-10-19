-- סימון הגעה למפגש: לכל שיוך משתתף-מפגש (להריץ פעם אחת, אפשר להריץ שוב בלי נזק)
alter table public.harpatka_attendance add column if not exists attended boolean not null default false;
alter table public.harpatka_attendance add column if not exists attended_at timestamptz;
notify pgrst, 'reload schema';
