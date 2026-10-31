-- סוגי מפגשים (31.10.26). כל מפגש שייך לסוג מפגש, ולכל סוג:
--   (1) פרטי ברירת מחדל למפגש חדש: שם, שעה, עיר, כמות משתתפים, הוראות הגעה, מדרגות מחיר ותמונה;
--   (2) מתי נפתח סימון ההגעה (att_lead), ההודעה לפני המפגש (event_msg) ומתי הכפתור שלה נפתח (event_open), שהיו עד עכשיו לכל מנהל (harpatka_admin_prefs);
--   (3) סטטוסים על מפגשים משלו (harpatka_statuses.type_id). סטטוס המערכת "משויך" (unpaid) משותף לכל הסוגים (type_id ריק).
-- המיגרציה יוצרת סוג אחד, "יוצאים להרפתקה", עם הנתונים של המפגש האחרון ועם ההגדרות הקיימות, ומשייכת אליו את כל המפגשים והסטטוסים.
-- אידמפוטנטי. בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_.

create table if not exists public.harpatka_meeting_types (
  id uuid primary key default gen_random_uuid(),
  name text not null default '' check (char_length(name) <= 80),
  sort int not null default 0,
  meeting_time time,
  city text check (city is null or char_length(city) <= 40),
  max_participants int,
  directions text check (directions is null or char_length(directions) <= 800),
  price_tiers jsonb,
  image_url text,
  att_lead text,
  event_open text,
  event_msg text,
  created_at timestamptz not null default now()
);
alter table public.harpatka_meeting_types enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_meeting_types;
create policy "harpatka admin all" on public.harpatka_meeting_types for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_meeting_types to authenticated, service_role;
do $$ begin alter publication supabase_realtime add table public.harpatka_meeting_types; exception when duplicate_object then null; end $$;

alter table public.harpatka_meetings add column if not exists type_id uuid references public.harpatka_meeting_types(id) on delete restrict;
alter table public.harpatka_statuses add column if not exists type_id uuid references public.harpatka_meeting_types(id) on delete cascade;

-- הסוג הראשון, מהמפגש האחרון ומההגדרות הקיימות (פעם אחת, רק כשעוד אין אף סוג)
do $$
declare
  m_time time; m_city text; m_max int; m_dirs text; m_tiers jsonb; m_img text;
  v_al text; v_eo text; v_em text;
begin
  if exists (select 1 from public.harpatka_meeting_types) then return; end if;
  select meeting_time, city, max_participants, directions, price_tiers, image_url
    into m_time, m_city, m_max, m_dirs, m_tiers, m_img
    from public.harpatka_meetings order by meeting_date desc, meeting_time desc limit 1;
  select att_lead, event_open, event_msg into v_al, v_eo, v_em
    from public.harpatka_admin_prefs where lower(email) = 'ofir.aviram@gmail.com';
  if v_al is null and v_eo is null and v_em is null then
    select att_lead, event_open, event_msg into v_al, v_eo, v_em
      from public.harpatka_admin_prefs where att_lead is not null or event_open is not null or event_msg is not null order by email limit 1;
  end if;
  insert into public.harpatka_meeting_types (name, sort, meeting_time, city, max_participants, directions, price_tiers, image_url, att_lead, event_open, event_msg)
  values ('יוצאים להרפתקה', 1, m_time, m_city, m_max, m_dirs, m_tiers, m_img, v_al, v_eo, nullif(btrim(coalesce(v_em, '')), ''));
end $$;

-- כל מפגש וכל סטטוס מפגש בלי סוג: לסוג הראשון (סטטוס המערכת "משויך" נשאר משותף לכל הסוגים)
update public.harpatka_meetings set type_id = (select id from public.harpatka_meeting_types order by sort, created_at limit 1) where type_id is null;
update public.harpatka_statuses set type_id = (select id from public.harpatka_meeting_types order by sort, created_at limit 1)
  where type_id is null and coalesce(scope, 'meeting') <> 'participant' and key <> 'unpaid';

notify pgrst, 'reload schema';
