-- ניהול כספים (27.10.26): הוצאות והכנסות שאינן תשלומי משתתפים, חד פעמיות או מחזוריות.
-- harpatka_finance: תנועה בודדת (הוצאה או הכנסה), אפשר לשייך למפגש או להשאיר כללית.
-- harpatka_finance_recurring: כלל מחזורי (שבועי, חודשי או שנתי); המופעים מחושבים בממשק מתאריך ההתחלה ועד היום.
-- אידמפוטנטי; להריץ על public, ובנוסף על test (אחרי החלפת public ב-test), בלי נתונים.
create table if not exists public.harpatka_finance (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('expense', 'income')),
  amount numeric(10, 2) not null check (amount > 0),
  entry_date date not null default current_date,
  title text not null,
  meeting_id uuid references public.harpatka_meetings(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.harpatka_finance_recurring (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('expense', 'income')),
  amount numeric(10, 2) not null check (amount > 0),
  title text not null,
  period text not null check (period in ('weekly', 'monthly', 'yearly')),
  start_date date not null default current_date,
  end_date date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.harpatka_finance enable row level security;
alter table public.harpatka_finance_recurring enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_finance;
create policy "harpatka admin all" on public.harpatka_finance for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
drop policy if exists "harpatka admin all" on public.harpatka_finance_recurring;
create policy "harpatka admin all" on public.harpatka_finance_recurring for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_finance, public.harpatka_finance_recurring to authenticated, service_role;
do $$ begin alter publication supabase_realtime add table public.harpatka_finance; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.harpatka_finance_recurring; exception when duplicate_object then null; end $$;
notify pgrst, 'reload schema';
