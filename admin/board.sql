-- ==========================================================================
-- יוצאים להרפתקה: לוח שיתופים (board/): פוסטים, תגובות בעץ ולייקים
--
-- הזדהות: כניסה עם גוגל + קישור לטלפון של משתתף קיים. הקישור ממתין לאישור בדף הניהול.
-- כל הגישה של הציבור דרך פונקציות (security definer): הטבלאות עצמן נעולות (RLS), כך שאי אפשר
-- לראות מי כתב מה. מי שממתין לאישור כותב ורואה רק את מה שכתב; באישור הכול מתפרסם.
-- להריץ פעם אחת (אפשר שוב בלי נזק). דורש admin/setup.sql / signup.sql / auth.sql.
-- ==========================================================================

create table if not exists public.harpatka_members (
  user_id        uuid primary key,
  email          text not null default '',
  google_name    text not null default '',
  phone_norm     text not null default '',
  participant_id uuid references public.harpatka_participants(id) on delete set null,
  status         text not null default 'pending' check (status in ('pending', 'approved', 'blocked')),
  created_at     timestamptz not null default now()
);
create unique index if not exists harpatka_members_part_uq on public.harpatka_members (participant_id) where status = 'approved' and participant_id is not null;

create table if not exists public.harpatka_posts (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid references public.harpatka_posts(id) on delete cascade,
  root_id    uuid,
  user_id    uuid not null references public.harpatka_members(user_id) on delete cascade,
  body       text not null check (length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists harpatka_posts_created on public.harpatka_posts (created_at desc);
create index if not exists harpatka_posts_user on public.harpatka_posts (user_id);

create table if not exists public.harpatka_likes (
  post_id uuid not null references public.harpatka_posts(id) on delete cascade,
  user_id uuid not null references public.harpatka_members(user_id) on delete cascade,
  primary key (post_id, user_id)
);

alter table public.harpatka_members enable row level security;
alter table public.harpatka_posts   enable row level security;
alter table public.harpatka_likes   enable row level security;
revoke all on public.harpatka_members, public.harpatka_posts, public.harpatka_likes from anon;
drop policy if exists "harpatka admin all" on public.harpatka_members;
drop policy if exists "harpatka admin all" on public.harpatka_posts;
drop policy if exists "harpatka admin all" on public.harpatka_likes;
create policy "harpatka admin all" on public.harpatka_members for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
create policy "harpatka admin all" on public.harpatka_posts   for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
create policy "harpatka admin all" on public.harpatka_likes   for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());

-- מי אני: null = עוד לא קישר טלפון; אחרת pending / approved / blocked
create or replace function public.harpatka_board_me()
returns text language sql stable security definer set search_path = public as $$
  select status from public.harpatka_members where user_id = auth.uid();
$$;

-- קישור חשבון גוגל לטלפון. התשובה זהה אם המספר קיים ואם לא (לא חושפים מי רשום); המנהל רואה בדף הניהול אם נמצא
create or replace function public.harpatka_board_claim(p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  m public.harpatka_members;
  pid uuid;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if found then return m.status; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id into pid from public.harpatka_participants where phone_norm = norm order by created_at limit 1;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id)
  values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid);
  return 'pending';
end $$;

-- הלוח: פוסטים ותגובות שמופיעים לציבור (כותב מאושר) + מה שכתבתי אני. בלי זהות הכותב
create or replace function public.harpatka_board_feed()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) from (
    select p.id, p.parent_id, p.root_id, p.body, p.created_at,
      (p.user_id = auth.uid()) as mine,
      (m.status <> 'approved') as pending,
      (select count(*) from public.harpatka_likes l join public.harpatka_members lm on lm.user_id = l.user_id
         where l.post_id = p.id and (lm.status = 'approved' or l.user_id = auth.uid())) as likes,
      exists (select 1 from public.harpatka_likes l where l.post_id = p.id and l.user_id = auth.uid()) as liked,
      (p.user_id = auth.uid() or exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = auth.uid())) as can_delete
    from public.harpatka_posts p join public.harpatka_members m on m.user_id = p.user_id
    where p.deleted_at is null and m.status <> 'blocked' and (m.status = 'approved' or p.user_id = auth.uid())
    order by p.created_at desc limit 500
  ) x;
$$;

create or replace function public.harpatka_board_post(p_body text, p_parent uuid default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m public.harpatka_members;
  body text := btrim(coalesce(p_body, ''));
  par public.harpatka_posts;
  pm public.harpatka_members;
  new_id uuid := gen_random_uuid();
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if not found then return 'no_member'; end if;
  if m.status = 'blocked' then return 'blocked'; end if;
  if body = '' then return 'empty'; end if;
  if length(body) > 2000 then return 'long'; end if;
  if m.status = 'pending' and (select count(*) from public.harpatka_posts where user_id = uid and deleted_at is null) >= 5 then return 'limit'; end if;
  if p_parent is not null then
    select * into par from public.harpatka_posts where id = p_parent and deleted_at is null;
    if not found then return 'no_parent'; end if;
    select * into pm from public.harpatka_members where user_id = par.user_id;
    if pm.status <> 'approved' and par.user_id <> uid then return 'no_parent'; end if;
  end if;
  insert into public.harpatka_posts (id, parent_id, root_id, user_id, body)
  values (new_id, p_parent, coalesce(par.root_id, new_id), uid, body);
  return 'ok';
end $$;

create or replace function public.harpatka_board_like(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m public.harpatka_members;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if not found or m.status = 'blocked' then return false; end if;
  if exists (select 1 from public.harpatka_likes where post_id = p_id and user_id = uid) then
    delete from public.harpatka_likes where post_id = p_id and user_id = uid; return false;
  end if;
  insert into public.harpatka_likes (post_id, user_id) values (p_id, uid);
  return true;
end $$;

-- מחיקה: כותב הפוסט/התגובה, או בעל הפוסט המקורי (שולט בכל התגובות בשרשור שלו)
create or replace function public.harpatka_board_delete(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.harpatka_posts;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into p from public.harpatka_posts where id = p_id;
  if not found then return 'none'; end if;
  if p.user_id <> uid and not exists (select 1 from public.harpatka_posts r where r.id = p.root_id and r.user_id = uid) then return 'denied'; end if;
  update public.harpatka_posts set deleted_at = now() where id = p_id;
  return 'ok';
end $$;

revoke all on function public.harpatka_board_me(), public.harpatka_board_claim(text), public.harpatka_board_feed(), public.harpatka_board_post(text, uuid), public.harpatka_board_like(uuid), public.harpatka_board_delete(uuid) from public;
grant execute on function public.harpatka_board_feed() to anon, authenticated;
grant execute on function public.harpatka_board_me(), public.harpatka_board_claim(text), public.harpatka_board_post(text, uuid), public.harpatka_board_like(uuid), public.harpatka_board_delete(uuid) to authenticated;

notify pgrst, 'reload schema';
