-- דרך איזה מנהל עבר הכסף, והתחשבנות בין מנהלים (27.10.26).
-- by_email: המנהל ששילם את ההוצאה מכיסו או שקיבל את ההכנסה (כתובת האימייל שלו). harpatka_finance_transfers: העברות כסף בין מנהלים שנרשמו להתחשבנות.
-- אידמפוטנטי; להריץ על public, ובנוסף על test (אחרי החלפת public ב-test, חוץ מ-public.harpatka_is_admin), בלי נתונים.
alter table public.harpatka_finance add column if not exists by_email text;
alter table public.harpatka_finance_recurring add column if not exists by_email text;
create table if not exists public.harpatka_finance_transfers (
  id uuid primary key default gen_random_uuid(),
  from_email text not null,
  to_email text not null,
  amount numeric(10, 2) not null check (amount > 0),
  transfer_date date not null default current_date,
  note text,
  created_at timestamptz not null default now()
);
alter table public.harpatka_finance_transfers enable row level security;
drop policy if exists "harpatka admin all" on public.harpatka_finance_transfers;
create policy "harpatka admin all" on public.harpatka_finance_transfers for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on public.harpatka_finance_transfers to authenticated, service_role;
do $$ begin alter publication supabase_realtime add table public.harpatka_finance_transfers; exception when duplicate_object then null; end $$;

create or replace function public.harpatka_finance_log_fn() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  tr boolean := (tg_table_name = 'harpatka_finance_transfers');
  rec boolean := (tg_table_name = 'harpatka_finance_recurring');
  o jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  n jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  r jsonb := coalesce(n, o);
  word text := case when tr then 'העברה בין מנהלים' else (case when r->>'kind' = 'income' then 'הכנסה' else 'הוצאה' end) || (case when rec then ' מחזורית' else '' end) end;
  per text := case r->>'period' when 'weekly' then 'כל שבוע' when 'monthly' then 'כל חודש' when 'yearly' then 'כל שנה' else '' end;
  who text := coalesce(auth.jwt()->>'email', 'מערכת');
  base text;
  diff text := '';
  k text;
  lab jsonb := '{"amount":"סכום","title":"תיאור","entry_date":"תאריך","start_date":"תאריך התחלה","end_date":"תאריך סיום","period":"חזרתיות","active":"פעיל","kind":"סוג","meeting_id":"שיוך למפגש","by_email":"דרך","from_email":"מאת","to_email":"אל","transfer_date":"תאריך"}';
  txt text;
begin
  if tr then
    base := '₪' || trim(to_char((r->>'amount')::numeric, 'FM999999990.##')) || ' · מ-' || split_part(r->>'from_email', '@', 1) || ' אל ' || split_part(r->>'to_email', '@', 1);
  else
    base := '₪' || trim(to_char((r->>'amount')::numeric, 'FM999999990.##')) || ' · ' || (r->>'title') || (case when rec then ' · ' || per else '' end) || (case when r->>'by_email' is not null then ' · דרך ' || split_part(r->>'by_email', '@', 1) else '' end);
  end if;
  if tg_op = 'INSERT' then
    txt := 'נוספה ' || word || ': ' || base;
  elsif tg_op = 'DELETE' then
    txt := 'נמחקה ' || word || ': ' || base;
  else
    for k in select jsonb_object_keys(lab) loop
      if (o->k) is distinct from (n->k) then
        diff := diff || (case when diff = '' then '' else ', ' end) || (lab->>k) || ' ' || coalesce(o->>k, '-') || ' ← ' || coalesce(n->>k, '-');
      end if;
    end loop;
    if diff = '' then return null; end if;
    txt := 'עודכנה ' || word || (case when tr then '' else ' "' || (n->>'title') || '"' end) || ': ' || diff;
  end if;
  insert into public.harpatka_finance_log (actor, action, entity, entity_id, summary)
  values (who, lower(tg_op), case when tr then 'transfer' when rec then 'recurring' else 'entry' end, (r->>'id')::uuid, txt);
  return null;
end $$;
drop trigger if exists harpatka_finance_log_t on public.harpatka_finance_transfers;
create trigger harpatka_finance_log_t after insert or update or delete on public.harpatka_finance_transfers for each row execute function public.harpatka_finance_log_fn();
notify pgrst, 'reload schema';
