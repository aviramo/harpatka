-- דף wa (שליחת וואטסאפ): מספרי הרשימה, סימוני "נשלח" / "לא לשלוח שוב" ונוסח ההודעה, בסכמה נפרדת harpatka בפרויקט ה-Supabase של floa.
-- לא נוגע בסכמת roster. הגישה רק לבעלים (אימייל מתוך ה-JWT של הכניסה עם גוגל), דרך פונקציות ב-public שמוגדרות security definer.
-- הרצה: supabase db query --linked --project-ref aexmnaxvahblveejsbup -f admin/wa-floa.sql   (אידמפוטנטי)
create schema if not exists harpatka;
create table if not exists harpatka.numbers (
  phone text primary key,                 -- +972XXXXXXXXX
  name text not null default '',
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  no_more boolean not null default false
);
create table if not exists harpatka.message (id int primary key default 1 check (id = 1), body text not null);
alter table harpatka.numbers enable row level security;
alter table harpatka.message enable row level security;
revoke all on schema harpatka from public, anon, authenticated;
revoke all on all tables in schema harpatka from public, anon, authenticated;

create or replace function public.harpatka_wa_norm(p text) returns text language sql immutable as $$
  select case when d = '' then '' when left(d, 3) = '972' then '+' || d when left(d, 1) = '0' then '+972' || substr(d, 2) else '+' || d end
  from (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as d) x $$;

create or replace function public.harpatka_wa_chk() returns void language plpgsql stable security definer set search_path = public as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'ofir.aviram@gmail.com' then raise exception 'forbidden' using errcode = '42501'; end if;
end $$;

create or replace function public.harpatka_wa_list() returns jsonb language plpgsql stable security definer set search_path = public, harpatka as $$
begin
  perform public.harpatka_wa_chk();
  return jsonb_build_object(
    'message', coalesce((select body from harpatka.message where id = 1), ''),
    'items', coalesce((select jsonb_agg(jsonb_build_object('phone', phone, 'name', name, 'sent_at', sent_at, 'no_more', no_more) order by created_at, phone) from harpatka.numbers), '[]'::jsonb));
end $$;

-- p_rows: [{phone, sent?: bool, no_more?: bool, name?: text, sent_at?: timestamptz}]; יוצר שורה אם אין (גם למשתתף רוסטר שאינו בקובץ)
create or replace function public.harpatka_wa_mark(p_rows jsonb) returns jsonb language plpgsql security definer set search_path = public, harpatka as $$
declare r jsonb; ph text; out jsonb := '[]'::jsonb; row harpatka.numbers;
begin
  perform public.harpatka_wa_chk();
  for r in select * from jsonb_array_elements(p_rows) loop
    ph := public.harpatka_wa_norm(r ->> 'phone');
    if ph = '' then continue; end if;
    insert into harpatka.numbers(phone, name) values (ph, coalesce(r ->> 'name', '')) on conflict (phone) do nothing;
    if r ? 'sent' then
      update harpatka.numbers set sent_at = case when (r ->> 'sent')::boolean then coalesce(sent_at, nullif(r ->> 'sent_at', '')::timestamptz, now()) else null end where phone = ph;
    end if;
    if r ? 'no_more' then update harpatka.numbers set no_more = (r ->> 'no_more')::boolean where phone = ph; end if;
    select * into row from harpatka.numbers where phone = ph;
    out := out || jsonb_build_array(jsonb_build_object('phone', row.phone, 'sent_at', row.sent_at, 'no_more', row.no_more));
  end loop;
  return out;
end $$;

create or replace function public.harpatka_wa_message(p_body text) returns text language plpgsql security definer set search_path = public, harpatka as $$
begin
  perform public.harpatka_wa_chk();
  if btrim(coalesce(p_body, '')) = '' then raise exception 'empty'; end if;
  insert into harpatka.message(id, body) values (1, p_body) on conflict (id) do update set body = excluded.body;
  return p_body;
end $$;

-- ייבוא: מוסיף מספרים חדשים בלבד (קיימים לא משתנים, כולל מי שסומן no_more). [{phone, name?}]
create or replace function public.harpatka_wa_import(p_rows jsonb) returns jsonb language plpgsql security definer set search_path = public, harpatka as $$
declare r jsonb; ph text; added int := 0; skipped int := 0; n int;
begin
  perform public.harpatka_wa_chk();
  for r in select * from jsonb_array_elements(p_rows) loop
    ph := public.harpatka_wa_norm(r ->> 'phone');
    if ph = '' then continue; end if;
    insert into harpatka.numbers(phone, name) values (ph, coalesce(r ->> 'name', '')) on conflict (phone) do nothing;
    get diagnostics n = row_count;
    if n > 0 then added := added + 1; else skipped := skipped + 1; end if;
  end loop;
  return jsonb_build_object('added', added, 'skipped', skipped);
end $$;

revoke all on function public.harpatka_wa_chk(), public.harpatka_wa_list(), public.harpatka_wa_mark(jsonb), public.harpatka_wa_message(text), public.harpatka_wa_import(jsonb) from public, anon;
grant execute on function public.harpatka_wa_list(), public.harpatka_wa_mark(jsonb), public.harpatka_wa_message(text), public.harpatka_wa_import(jsonb) to authenticated;
notify pgrst, 'reload schema';
