-- קרדיט: ביטול מפגש בלי להחזיר כסף (הסכום נשאר כקרדיט למשתתף), ושימוש בקרדיט בתשלום חדש
alter table public.harpatka_payments drop constraint if exists harpatka_payments_kind_check;
alter table public.harpatka_payments add constraint harpatka_payments_kind_check check (kind in ('payment', 'refund', 'credit'));
alter table public.harpatka_payments add column if not exists from_credit boolean not null default false;
notify pgrst, 'reload schema';
