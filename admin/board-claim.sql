-- חיבור טלפון ללוח: רק מספר של משתתף רשום. מספר שלא נמצא = 'not_registered' (בלי ליצור חיבור), והמשתמש מתבקש להירשם למפגש תחילה.
-- חיבור קיים בלי משתתף (מלפני השינוי) מקבל הזדמנות לנסות שוב.
create or replace function public.harpatka_board_claim(p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  m public.harpatka_members;
  pid uuid;
  adm boolean := public.harpatka_is_admin();
  had boolean;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  had := found;
  if had and (m.participant_id is not null or m.status = 'approved') then return m.status; end if;
  if norm = '' then return 'invalid_phone'; end if;
  select id into pid from public.harpatka_participants where phone_norm = norm order by created_at limit 1;
  if pid is null and not adm then return 'not_registered'; end if;
  if had then
    update public.harpatka_members set participant_id = pid, phone_norm = norm where user_id = uid;
    return m.status;
  end if;
  insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status)
  values (uid, lower(coalesce(auth.jwt() ->> 'email', '')), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', ''), norm, pid,
          case when adm then 'approved' else 'pending' end);
  return case when adm then 'approved' else 'pending' end;
end $$;
revoke all on function public.harpatka_board_claim(text) from public;
grant execute on function public.harpatka_board_claim(text) to authenticated;
