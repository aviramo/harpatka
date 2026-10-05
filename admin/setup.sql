-- ==========================================================================
-- יוצאים להרפתקה: הקמה מלאה של פרויקט Supabase ייעודי (הכול בהרצה אחת)
--
-- להריץ פעם אחת, כולו, בפרויקט החדש: SQL Editor -> New query -> להדביק -> Run.
-- אפשר להריץ שוב בלי נזק.
--
-- מה זה בונה: טבלאות (משתתפים, מפגשים, שיוך), נרמול טלפונים E.164 וזיהוי כפילויות,
-- פונקציית ההרשמה של הטופס (harpatka_signup), ונעילה לפי מייל מורשה (כניסה עם גוגל).
-- בלי מדיניות פתוחה: מההתחלה רק מנהלים רואים משתתפים.
--
-- ⚠️ לפני ההרצה: להחליף את המייל בשורת ה-insert של harpatka_admins אם צריך.
-- ==========================================================================

-- 1. טבלאות
create table if not exists public.harpatka_participants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  phone       text not null default '',
  phone_norm  text not null default '',
  source      text not null default '',
  age         int,
  age_set_at  date not null default current_date,
  note        text not null default '',
  created_at  timestamptz not null default now()
);
create table if not exists public.harpatka_meetings (
  id            uuid primary key default gen_random_uuid(),
  meeting_date  date not null,
  meeting_time  time not null default '20:00',
  created_at    timestamptz not null default now()
);
create unique index if not exists harpatka_meetings_dt_uq on public.harpatka_meetings (meeting_date, meeting_time);
create table if not exists public.harpatka_attendance (
  participant_id  uuid not null references public.harpatka_participants(id) on delete cascade,
  meeting_id      uuid not null references public.harpatka_meetings(id) on delete cascade,
  paid            boolean not null default false,
  created_at      timestamptz not null default now(),
  primary key (participant_id, meeting_id)
);
alter table public.harpatka_participants enable row level security;
alter table public.harpatka_meetings     enable row level security;
alter table public.harpatka_attendance   enable row level security;

-- המפגש הראשון
insert into public.harpatka_meetings (meeting_date, meeting_time) values ('2026-10-25', '20:00') on conflict do nothing;

-- 2. נרמול טלפונים, כפילויות והפונקציה harpatka_signup
alter table public.harpatka_participants add column if not exists phone_norm text not null default '';
alter table public.harpatka_participants add column if not exists source     text not null default '';

-- 1. נרמול (אותה לוגיקה בדיוק כמו ב-index.html)
create or replace function public.harpatka_normalize_phone(p text)
returns text language plpgsql immutable as $$
declare
  raw  text := trim(coalesce(p, ''));
  plus boolean;
  d    text;
begin
  if raw = '' then return ''; end if;
  plus := left(raw, 1) = '+';
  d := regexp_replace(raw, '\D', '', 'g');
  if d = '' then return ''; end if;
  if left(d, 2) = '00' then plus := true; d := substr(d, 3); end if;          -- 00972...
  if plus then
    if left(d, 4) = '9720' then d := '972' || substr(d, 5); end if;           -- +972(0)50...
    if length(d) < 8 or length(d) > 15 or left(d, 1) = '0' then return ''; end if;
    if left(d, 3) = '972' and substr(d, 4) !~ '^(5\d{8}|7\d{8}|[23489]\d{7})$' then return ''; end if;
    return '+' || d;
  end if;
  if left(d, 1) = '0' then                                                     -- ישראלי מקומי
    if d ~ '^0(5\d{8}|7\d{8}|[23489]\d{7})$' then return '+972' || substr(d, 2); end if;
    return '';
  end if;
  return '';
end $$;

-- 2. כל הוספה/עדכון של טלפון (גם מדף הניהול) מנורמלים אוטומטית
create or replace function public.harpatka_participants_phone_trg()
returns trigger language plpgsql as $$
begin
  new.phone_norm := public.harpatka_normalize_phone(new.phone);
  return new;
end $$;

drop trigger if exists harpatka_participants_phone on public.harpatka_participants;
create trigger harpatka_participants_phone
  before insert or update of phone on public.harpatka_participants
  for each row execute function public.harpatka_participants_phone_trg();

-- 3. נרמול הרשומות הקיימות
update public.harpatka_participants set phone_norm = public.harpatka_normalize_phone(phone)
  where phone_norm is distinct from public.harpatka_normalize_phone(phone);

-- 4. אינדקס ייחודי למניעת כפילויות (נדלג עם הודעה אם כבר יש כפילויות קיימות: למזג ידנית ולהריץ שוב)
do $$
begin
  create unique index if not exists harpatka_participants_phone_norm_uq
    on public.harpatka_participants (phone_norm) where phone_norm <> '';
exception when unique_violation then
  raise notice 'יש כפילויות קיימות של מספרי טלפון: למזג אותן ידנית ולהריץ שוב כדי להפעיל את האינדקס הייחודי';
end $$;

-- 5. הרשמה מהאתר. מחזירה: created | exists | invalid_name | invalid_phone | invalid_age
--    המשתתף נקשר אוטומטית למפגש הקרוב (המפגש שמוצג בבאנר: התאריך הקרוב ביותר שעוד לא עבר, שעון ישראל)
--    כ"טרם שילם" (paid = false). אם המשתתף כבר קיים (אותו מספר) הוא נקשר למפגש הקרוב אם עוד לא היה מקושר.
--    הגיל נשמר ב-age (ו-age_set_at = היום), כמו בדף הניהול. מספר שכבר קיים בלי גיל: הגיל מתעדכן.
drop function if exists public.harpatka_signup(text, text);   -- הגרסה הישנה (בלי גיל)
create or replace function public.harpatka_signup(p_name text, p_phone text, p_age int default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  nm  text := trim(coalesce(p_name, ''));
  pid uuid;
  mid uuid;
  res text := 'created';
begin
  if char_length(nm) < 2 or char_length(nm) > 60 then return 'invalid_name'; end if;
  if n = '' then return 'invalid_phone'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;

  select id into mid from public.harpatka_meetings
    where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
    order by meeting_date, meeting_time limit 1;

  select id into pid from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null then
    res := 'exists';
    update public.harpatka_participants set age = p_age, age_set_at = current_date where id = pid and age is null;
  else
    begin
      insert into public.harpatka_participants (name, phone, age, age_set_at, source)
        values (nm, n, p_age, current_date, 'site')   -- phone_norm נקבע בטריגר
        returning id into pid;
    exception when unique_violation then
      select id into pid from public.harpatka_participants where phone_norm = n limit 1;
      res := 'exists';
    end;
  end if;

  if mid is not null and pid is not null then
    insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false)
      on conflict (participant_id, meeting_id) do nothing;
  end if;
  return res;
end $$;

revoke all on function public.harpatka_signup(text, text, int) from public;
grant execute on function public.harpatka_signup(text, text, int) to anon, authenticated;

notify pgrst, 'reload schema';

-- 3. מנהלים ומדיניות גישה
create table if not exists public.harpatka_admins (email text primary key);
alter table public.harpatka_admins enable row level security;     -- בלי מדיניות: אף אחד לא קורא ישירות
revoke all on public.harpatka_admins from anon, authenticated;
insert into public.harpatka_admins (email) values ('ofir.aviram@gmail.com') on conflict do nothing;   -- מיילים מורשים (כניסה עם גוגל)

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

grant select, insert, update, delete on public.harpatka_participants, public.harpatka_meetings, public.harpatka_attendance to authenticated;
revoke all on public.harpatka_participants from anon;
revoke all on public.harpatka_attendance   from anon;
revoke insert, update, delete on public.harpatka_meetings from anon;
grant select on public.harpatka_meetings to anon;

notify pgrst, 'reload schema';
