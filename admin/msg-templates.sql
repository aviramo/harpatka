-- תבניות הודעה לוואטסאפ (31.10.26). תבנית = שם ונוסח (עם שדות כמו {שם} ו-{התחלה}), של סוג מפגש (לכל מפגשיו) או של מפגש אחד (בנוסף לאלה של הסוג).
-- בדף הניהול בוחרים תבנית בעמודת הוואטסאפ של הרשימה, וקישור הוואטסאפ של כל משתתף נפתח עם ההודעה המוכנה; אחרי החזרה מוואטסאפ מאשרים שנשלח, והסימון נשמר (harpatka_msg_sent).
-- לכל סוג נוצרת תבנית אחת מנוסח "ההודעה לפני המפגש" שלו, כדי שהנוסח הקיים לא יאבד (עמודת "שליחת פרטי המפגש" ברשימה בוטלה).
-- אידמפוטנטי. בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_ (חוץ מ-public.harpatka_is_admin).

create table if not exists public.harpatka_msg_templates (
  id uuid primary key default gen_random_uuid(),
  type_id uuid references public.harpatka_meeting_types(id) on delete cascade,
  meeting_id uuid references public.harpatka_meetings(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 60),
  body text not null default '' check (char_length(body) <= 2000),
  sort int not null default 0,
  created_at timestamptz not null default now(),
  check ((type_id is null) <> (meeting_id is null))
);
create index if not exists harpatka_msg_templates_type on public.harpatka_msg_templates (type_id);
create index if not exists harpatka_msg_templates_meeting on public.harpatka_msg_templates (meeting_id);
alter table public.harpatka_msg_templates enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_msg_templates;
create policy "harpatka admin all" on public.harpatka_msg_templates for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_msg_templates to authenticated, service_role;
do $$ begin alter publication supabase_realtime add table public.harpatka_msg_templates; exception when duplicate_object then null; end $$;

-- תבנית אחת לכל סוג, מנוסח ההודעה לפני המפגש (או נוסח ברירת המחדל), רק לסוג שעוד אין לו תבניות
insert into public.harpatka_msg_templates (type_id, name, body, sort)
select mt.id, 'הודעה לפני המפגש',
  coalesce(nullif(btrim(mt.event_msg), ''), E'ההתרגשות בעיצומה 🕺💃\nהיום זה קורה!\nנפגשים הערב\n{הוראות הגעה}\n\nמומלץ להגיע בבגדים נוחים ובקבוק מים.\nהתכנסות: {התכנסות} מתחילים ב{התחלה}\nהמפגש עד {סיום}\n\nמחכים לכם\nאופיר והדר 🩷'),
  0
from public.harpatka_meeting_types mt
where not exists (select 1 from public.harpatka_msg_templates x where x.type_id = mt.id);

-- מעקב שליחה: מי קיבל איזו תבנית. מפתח התבנית = מזהה התבנית, או 'dir' ל"הוראות הגעה" של המפגש. שורה אחת לכל משתתף, מפגש ותבנית
create table if not exists public.harpatka_msg_sent (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.harpatka_participants(id) on delete cascade,
  meeting_id uuid not null references public.harpatka_meetings(id) on delete cascade,
  tpl_key text not null,
  sent_at timestamptz not null default now(),
  sent_by text,
  unique (participant_id, meeting_id, tpl_key)
);
create index if not exists harpatka_msg_sent_meeting on public.harpatka_msg_sent (meeting_id);
alter table public.harpatka_msg_sent enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_msg_sent;
create policy "harpatka admin all" on public.harpatka_msg_sent for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_msg_sent to authenticated, service_role;
do $$ begin alter publication supabase_realtime add table public.harpatka_msg_sent; exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
