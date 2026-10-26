-- מיגרציה לסביבת האמת (public), שלב 1: טבלת הסטטוסים וששת הסטטוסים המובנים (27.10.26)
-- תוספת בלבד: לא משנה ולא מוחק שום נתון קיים; הממשק הישן (admin/) ממשיך לעבוד ללא שינוי.
-- מפתחות הסטטוסים זהים לדגלים הקיימים ב-harpatka_attendance (paid, exempt, will_pay, maybe, pay_requested_at), ולכן כל השיוכים הקיימים מוצגים באותו סטטוס.
-- שאר המיגרציה (עמודות, טבלאות תשלומים, טריגרים) בשלבים הבאים; שמות ומפתחות לפי test-features.sql סעיף 2.
begin;

create table if not exists public.harpatka_statuses (
  key text primary key,
  label text not null,
  color text not null,
  sort int not null,
  scope text not null default 'meeting'
);

insert into public.harpatka_statuses (key, label, color, sort, scope) values
  ('paid', 'שילם', 'green', 1, 'meeting'),
  ('willpay', 'ישלם', 'neutral', 2, 'meeting'),
  ('exempt', 'חינם', 'sky', 3, 'meeting'),
  ('maybe', 'ספונטני', 'sky', 4, 'meeting'),
  ('requested', 'בטיפול', 'amber', 5, 'meeting'),
  ('unpaid', 'חדש', 'red', 99, 'meeting')
on conflict (key) do nothing;

alter table public.harpatka_statuses enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_statuses;
create policy "harpatka admin all" on public.harpatka_statuses for all to authenticated
  using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_statuses to authenticated, service_role;

do $$ begin
  alter publication supabase_realtime add table public.harpatka_statuses;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
commit;
