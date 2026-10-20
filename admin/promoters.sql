-- יחצנים ועמלות + סכום ששולם בפועל (להריץ פעם אחת, אפשר להריץ שוב בלי נזק)
create table if not exists public.harpatka_promoters (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  rate_type  text not null default 'fixed' check (rate_type in ('fixed', 'percent')),   -- fixed = סכום קבוע בשקלים, percent = אחוז מהתשלום
  rate       numeric not null default 0,
  created_at timestamptz not null default now()
);
alter table public.harpatka_promoters enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_promoters;
create policy "harpatka admin all" on public.harpatka_promoters for all to authenticated
  using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

-- יחצן ברירת מחדל למשתתף (מי שהביא אותו)
alter table public.harpatka_participants add column if not exists promoter_id uuid references public.harpatka_promoters(id) on delete set null;
-- פרטי התשלום לכל שיוך משתתף-מפגש: כמה שולם, מי היחצן ובכמה (עמלה), ומתי
alter table public.harpatka_attendance add column if not exists paid_amount numeric;
alter table public.harpatka_attendance add column if not exists promoter_id uuid references public.harpatka_promoters(id) on delete set null;
alter table public.harpatka_attendance add column if not exists commission numeric;
alter table public.harpatka_attendance add column if not exists paid_at timestamptz;
-- תשלומים קיימים נרשמו כ-80 ₪ (לפי הדיווח)
update public.harpatka_attendance set paid_amount = 80 where paid = true and exempt = false and paid_amount is null;

do $$ begin
  alter publication supabase_realtime add table public.harpatka_promoters;
exception when duplicate_object then null; when undefined_object then null;
end $$;
notify pgrst, 'reload schema';
