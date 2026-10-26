-- יומן שינויים לכספים (27.10.26): כל הוספה, עדכון ומחיקה של הוצאה או הכנסה (בודדת או מחזורית) נרשמים בטריגר, עם מי ביצע ומתי.
-- אידמפוטנטי; להריץ על public, ובנוסף על test (אחרי החלפת public ב-test, חוץ מ-public.harpatka_is_admin), בלי נתונים.
create table if not exists public.harpatka_finance_log (
  id uuid primary key default gen_random_uuid(),
  at timestamptz not null default now(),
  actor text,
  action text not null,
  entity text not null,
  entity_id uuid,
  summary text not null
);
alter table public.harpatka_finance_log enable row level security;
drop policy if exists "harpatka admin read" on public.harpatka_finance_log;
create policy "harpatka admin read" on public.harpatka_finance_log for select to authenticated using (public.harpatka_is_admin());
grant select on public.harpatka_finance_log to authenticated;
grant all on public.harpatka_finance_log to service_role;

create or replace function public.harpatka_finance_log_fn() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  rec boolean := (tg_table_name = 'harpatka_finance_recurring');
  o jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  n jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  r jsonb := coalesce(n, o);
  word text := (case when r->>'kind' = 'income' then 'הכנסה' else 'הוצאה' end) || (case when rec then ' מחזורית' else '' end);
  per text := case r->>'period' when 'weekly' then 'כל שבוע' when 'monthly' then 'כל חודש' when 'yearly' then 'כל שנה' else '' end;
  who text := coalesce(auth.jwt()->>'email', 'מערכת');
  base text := '₪' || trim(to_char((r->>'amount')::numeric, 'FM999999990.##')) || ' · ' || (r->>'title') || (case when rec then ' · ' || per else '' end);
  diff text := '';
  k text;
  lab jsonb := '{"amount":"סכום","title":"תיאור","entry_date":"תאריך","start_date":"תאריך התחלה","end_date":"תאריך סיום","period":"חזרתיות","active":"פעיל","kind":"סוג","meeting_id":"שיוך למפגש"}';
  txt text;
begin
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
    txt := 'עודכנה ' || word || ' "' || (n->>'title') || '": ' || diff;
  end if;
  insert into public.harpatka_finance_log (actor, action, entity, entity_id, summary)
  values (who, lower(tg_op), case when rec then 'recurring' else 'entry' end, (r->>'id')::uuid, txt);
  return null;
end $$;

drop trigger if exists harpatka_finance_log_t on public.harpatka_finance;
create trigger harpatka_finance_log_t after insert or update or delete on public.harpatka_finance for each row execute function public.harpatka_finance_log_fn();
drop trigger if exists harpatka_finance_log_t on public.harpatka_finance_recurring;
create trigger harpatka_finance_log_t after insert or update or delete on public.harpatka_finance_recurring for each row execute function public.harpatka_finance_log_fn();
notify pgrst, 'reload schema';
