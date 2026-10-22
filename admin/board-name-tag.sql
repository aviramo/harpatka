-- תגית שם פרטי בפוסט/תגובה: לא אוטומטית. הכותב בוחר (ברירת מחדל בטופס: מופיעה, ואפשר להסיר), ויכול להסיר/להחזיר אחרי הפרסום.

alter table public.harpatka_posts add column if not exists show_name boolean not null default true;

-- הפרופיל: גם שם פרטי להצגה בתגית
create or replace function public.harpatka_board_profile()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', m.status, 'can_share', m.participant_id is not null,
    'can_post', public.harpatka_is_admin() or exists (select 1 from public.harpatka_attendance at join public.harpatka_participants pp on pp.id = at.participant_id where at.participant_id = m.participant_id and pp.active),
    'name', coalesce(pa.name, nullif(m.google_name, ''), m.email),
    'is_admin', public.harpatka_is_admin(),
    'first_name', coalesce(nullif(pa.first_name, ''), nullif(split_part(btrim(m.google_name), ' ', 1), ''), ''))
  from public.harpatka_members m left join public.harpatka_participants pa on pa.id = m.participant_id where m.user_id = auth.uid();
$$;

-- הכותב מסיר/מחזיר את תגית השם הפרטי בפוסט או בתגובה שלו
create or replace function public.harpatka_board_set_name(p_id uuid, p_show boolean)
returns text language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'auth'; end if;
  update public.harpatka_posts set show_name = coalesce(p_show, false) where id = p_id and user_id = auth.uid() and deleted_at is null;
  if not found then return 'none'; end if;
  return 'ok';
end $$;
revoke all on function public.harpatka_board_set_name(uuid, boolean) from public;
grant execute on function public.harpatka_board_set_name(uuid, boolean) to authenticated;

-- (הפונקציות harpatka_board_post ו-harpatka_board_feed המעודכנות ב-board-phone.sql וב-board-hide.sql)

-- ברירת מחדל: השם מוצג (הכותב יכול להסיר). פוסטים שנכתבו לפני כן עודכנו להציג שם.
alter table public.harpatka_posts alter column show_name set default true;
