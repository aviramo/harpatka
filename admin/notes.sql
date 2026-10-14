-- הערות על משתתפים (כמו CRM): כמה הערות לכל משתתף, עם מי כתב ומתי.
-- להריץ פעם אחת ב-SQL Editor (אפשר להריץ שוב בלי נזק).
create table if not exists public.harpatka_notes (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.harpatka_participants(id) on delete cascade,
  body           text not null,
  author_email   text,
  author_name    text,
  created_at     timestamptz not null default now()
);
create index if not exists harpatka_notes_participant_idx on public.harpatka_notes (participant_id, created_at desc);
alter table public.harpatka_notes enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_notes;
create policy "harpatka admin all" on public.harpatka_notes for all to authenticated
  using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

-- העברת ההערה הקצרה הישנה (participants.note) להערה ראשונה, פעם אחת בלבד
insert into public.harpatka_notes (participant_id, body, author_name)
select p.id, trim(p.note), 'מערכת'
from public.harpatka_participants p
where coalesce(trim(p.note), '') <> ''
  and not exists (select 1 from public.harpatka_notes n where n.participant_id = p.id);

-- זמן אמת
do $$ begin
  alter publication supabase_realtime add table public.harpatka_notes;
exception when duplicate_object then null; when undefined_object then null;
end $$;

notify pgrst, 'reload schema';
