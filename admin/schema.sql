-- ==========================================================================
-- יוצאים להרפתקה: ניהול משתתפים (admin/)
--
-- להריץ פעם אחת, כולו, ב-Supabase של floa:
-- SQL Editor -> New query -> להדביק -> Run.
-- אפשר להריץ שוב בלי נזק.
--
-- ⚠️ זמני: כל עוד אין התחברות, הטבלאות פתוחות לקריאה ולכתיבה לכל מי שמחזיק
-- את המפתח הציבורי (anon). לא להכניס נתונים אמיתיים לפני שמחליפים את
-- המדיניות "harpatka temp open" במדיניות לפי מייל מחובר.
-- ==========================================================================

create table if not exists public.harpatka_participants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  phone       text not null default '',
  -- הגיל כפי שהוקלד, ותאריך ההקלדה. הגיל המוצג = age + שנים מלאות מאז age_set_at
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

-- משתתף <-> מפגש, עם סטטוס תשלום
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

grant select, insert, update, delete on public.harpatka_participants to anon, authenticated;
grant select, insert, update, delete on public.harpatka_meetings     to anon, authenticated;
grant select, insert, update, delete on public.harpatka_attendance   to anon, authenticated;

-- ⚠️ זמני, עד ההתחברות דרך גוגל
drop policy if exists "harpatka temp open" on public.harpatka_participants;
drop policy if exists "harpatka temp open" on public.harpatka_meetings;
drop policy if exists "harpatka temp open" on public.harpatka_attendance;
create policy "harpatka temp open" on public.harpatka_participants for all to anon, authenticated using (true) with check (true);
create policy "harpatka temp open" on public.harpatka_meetings     for all to anon, authenticated using (true) with check (true);
create policy "harpatka temp open" on public.harpatka_attendance   for all to anon, authenticated using (true) with check (true);

notify pgrst, 'reload schema';
