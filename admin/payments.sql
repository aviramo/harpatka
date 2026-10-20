-- יומן תשלומים: כל סימון תשלום או החזר יוצר רשומה חדשה (נשמר גם כשהסטטוס משתנה). נראה למשתתף וליחצן.
create table if not exists public.harpatka_payments (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.harpatka_participants(id) on delete cascade,
  meeting_id     uuid references public.harpatka_meetings(id) on delete set null,
  kind           text not null check (kind in ('payment', 'refund')),
  amount         numeric not null default 0,   -- תמיד חיובי; החזר = כסף שחזר למשתתף
  promoter_id    uuid references public.harpatka_promoters(id) on delete set null,
  commission     numeric,                      -- תמיד חיובי; בהחזר = העמלה שמבוטלת
  author_name    text,
  created_at     timestamptz not null default now()
);
create index if not exists harpatka_payments_p_idx on public.harpatka_payments (participant_id, created_at desc);
create index if not exists harpatka_payments_pr_idx on public.harpatka_payments (promoter_id, created_at desc);
alter table public.harpatka_payments enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_payments;
create policy "harpatka admin all" on public.harpatka_payments for all to authenticated
  using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
-- מילוי היסטורי: תשלומים שכבר סומנו (פעם אחת, רק כשהיומן ריק)
insert into public.harpatka_payments (participant_id, meeting_id, kind, amount, promoter_id, commission, author_name, created_at)
select a.participant_id, a.meeting_id, 'payment', coalesce(a.paid_amount, 80), a.promoter_id, a.commission, 'מערכת', coalesce(a.paid_at, a.created_at, now())
from public.harpatka_attendance a
where a.paid = true and a.exempt = false
  and not exists (select 1 from public.harpatka_payments);
do $$ begin
  alter publication supabase_realtime add table public.harpatka_payments;
exception when duplicate_object then null; when undefined_object then null;
end $$;
notify pgrst, 'reload schema';
