-- תשלומים ליחצנים (התחשבנות): כל שורה = תשלום שביצענו ליחצן. החוב ליחצן = עמלות שנצברו פחות התשלומים האלה.
create table if not exists public.harpatka_promoter_payments (
  id          uuid primary key default gen_random_uuid(),
  promoter_id uuid not null references public.harpatka_promoters(id) on delete cascade,
  amount      numeric not null check (amount > 0),
  paid_at     date not null default current_date,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists harpatka_promoter_payments_idx on public.harpatka_promoter_payments (promoter_id, paid_at desc);
alter table public.harpatka_promoter_payments enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_promoter_payments;
create policy "harpatka admin all" on public.harpatka_promoter_payments for all to authenticated
  using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
do $$ begin
  alter publication supabase_realtime add table public.harpatka_promoter_payments;
exception when duplicate_object then null; when undefined_object then null;
end $$;
notify pgrst, 'reload schema';
