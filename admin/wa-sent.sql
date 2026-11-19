-- דף wa: סימוני "נשלח" / "לא לשלוח שוב" ונוסח ההודעה נשמרים ב-DB. נשמר גיבוב של הטלפון (sha256), לא המספר. הרצה: sed 's/__S__/public/g' (וגם test)
create table if not exists __S__.harpatka_wa_sent (h text primary key, kind text not null default 'sent' check (kind in ('sent','skip')), sent_at timestamptz not null default now());
create table if not exists __S__.harpatka_wa_msg (id int primary key default 1 check (id = 1), body text not null);
alter table __S__.harpatka_wa_sent enable row level security;
alter table __S__.harpatka_wa_msg enable row level security;
create or replace function __S__.harpatka_wa_get() returns jsonb language sql security definer set search_path = __S__ as $$
  select jsonb_build_object('marks', coalesce((select jsonb_object_agg(h, kind) from __S__.harpatka_wa_sent), '{}'::jsonb), 'msg', (select body from __S__.harpatka_wa_msg)) $$;
create or replace function __S__.harpatka_wa_set(p_h text, p_kind text) returns void language plpgsql security definer set search_path = __S__ as $$
begin
  if p_h !~ '^[0-9a-f]{64}$' then raise exception 'bad'; end if;
  if p_kind in ('sent','skip') then insert into __S__.harpatka_wa_sent(h, kind) values (p_h, p_kind) on conflict (h) do update set kind = excluded.kind, sent_at = now();
  else delete from __S__.harpatka_wa_sent where h = p_h; end if;
end $$;
create or replace function __S__.harpatka_wa_setmsg(p_body text) returns void language sql security definer set search_path = __S__ as $$
  insert into __S__.harpatka_wa_msg(id, body) values (1, p_body) on conflict (id) do update set body = excluded.body $$;
drop function if exists __S__.harpatka_wa_clear();
grant execute on function __S__.harpatka_wa_get(), __S__.harpatka_wa_set(text, text), __S__.harpatka_wa_setmsg(text) to anon, authenticated;
