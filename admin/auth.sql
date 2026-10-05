-- ==========================================================================
-- יוצאים להרפתקה: נעילת דף הניהול (admin/) לפי כניסה עם גוגל (הזדהות של floa)
--
-- להריץ פעם אחת, כולו, ב-Supabase של floa: SQL Editor -> New query -> להדביק -> Run.
-- אפשר להריץ שוב בלי נזק. (דורש ש-admin/schema.sql ו-admin/signup.sql כבר הורצו.)
--
-- מה זה עושה:
--  * רק מיילים שברשימה harpatka_admins (חשבון גוגל מחובר) יכולים לקרוא ולכתוב משתתפים, מפגשים ושיוכים.
--  * מי שלא מחובר (anon), כלומר כל מבקר באתר, לא רואה כלום, חוץ מ:
--      - תאריך ושעה של מפגשים (הבאנר בדף הבית קורא אותם)
--      - ההרשמה מהטופס, שעוברת דרך הפונקציה harpatka_signup (security definer) ולא דורשת הרשאות לטבלה.
--
-- ⚠️ לפני ההרצה: להיכנס פעם אחת ל-https://harpatka.co.il/admin/ עם גוגל ולוודא שהכניסה עובדת.
-- ⚠️ ב-Supabase: Authentication -> URL Configuration -> Redirect URLs: להוסיף https://harpatka.co.il/admin/
-- להוספת מייל מורשה: insert into public.harpatka_admins (email) values ('name@gmail.com');
-- ==========================================================================

create table if not exists public.harpatka_admins (email text primary key);
alter table public.harpatka_admins enable row level security;     -- בלי מדיניות: אף אחד לא קורא ישירות
revoke all on public.harpatka_admins from anon, authenticated;
insert into public.harpatka_admins (email) values ('ofir.aviram@gmail.com') on conflict do nothing;

create or replace function public.harpatka_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.harpatka_admins a where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
revoke all on function public.harpatka_is_admin() from public;
grant execute on function public.harpatka_is_admin() to anon, authenticated;

-- הסרת המדיניות הפתוחה הזמנית
drop policy if exists "harpatka temp open" on public.harpatka_participants;
drop policy if exists "harpatka temp open" on public.harpatka_meetings;
drop policy if exists "harpatka temp open" on public.harpatka_attendance;

-- מנהלים: הכול
drop policy if exists "harpatka admin all" on public.harpatka_participants;
drop policy if exists "harpatka admin all" on public.harpatka_meetings;
drop policy if exists "harpatka admin all" on public.harpatka_attendance;
create policy "harpatka admin all" on public.harpatka_participants for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
create policy "harpatka admin all" on public.harpatka_meetings     for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
create policy "harpatka admin all" on public.harpatka_attendance   for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

-- ציבור: רק קריאת מפגשים (לבאנר), בלי משתתפים ובלי שיוכים
drop policy if exists "harpatka public read meetings" on public.harpatka_meetings;
create policy "harpatka public read meetings" on public.harpatka_meetings for select to anon, authenticated using (true);

revoke all on public.harpatka_participants from anon;
revoke all on public.harpatka_attendance   from anon;
revoke insert, update, delete on public.harpatka_meetings from anon;
grant select on public.harpatka_meetings to anon;

notify pgrst, 'reload schema';
