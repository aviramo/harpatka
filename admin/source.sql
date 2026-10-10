-- ==========================================================================
-- סימון נרשמים שהגיעו ממודעה בתשלום (הקישור במודעות: https://harpatka.co.il/?s=p)
-- להריץ פעם אחת ב-Supabase SQL Editor. משתתף חדש שהגיע עם s=p נשמר עם source = 'site-ad'
-- (בדף הניהול מוצג "ממומן"); כל השאר נשמרים כמו קודם (source = 'site'). אין שינוי בטבלאות.
-- עד שמריצים: ההרשמה באתר ממשיכה לעבוד כרגיל, רק בלי הסימון.
-- ==========================================================================

drop function if exists public.harpatka_signup(text, text, int);
drop function if exists public.harpatka_signup(text, text, int, text);
drop function if exists public.harpatka_signup(text, text, int, text, text);
create or replace function public.harpatka_signup(p_name text, p_phone text, p_age int default null, p_gender text default null, p_src text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  nm  text := trim(coalesce(p_name, ''));
  pid uuid;
  mid uuid;
  md  date;
  mt  time;
  res text := 'created';
begin
  if char_length(nm) < 2 or char_length(nm) > 60 then return 'invalid_name'; end if;
  if n = '' then return 'invalid_phone'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is not null and p_gender not in ('male', 'female') then return 'invalid_gender'; end if;

  select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
    where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
    order by meeting_date, meeting_time limit 1;

  select id into pid from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null then
    res := 'exists';
    update public.harpatka_participants set age = p_age, age_set_at = current_date where id = pid and age is null;
    update public.harpatka_participants set gender = p_gender where id = pid and gender is null and p_gender is not null;
  else
    begin
      insert into public.harpatka_participants (name, phone, age, age_set_at, source, gender)
        values (nm, n, p_age, current_date, case when p_src = 'p' then 'site-ad' else 'site' end, p_gender)
        returning id into pid;
    exception when unique_violation then
      select id into pid from public.harpatka_participants where phone_norm = n limit 1;
      res := 'exists';
    end;
  end if;

  if mid is not null and pid is not null then
    insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false)
      on conflict (participant_id, meeting_id) do nothing;
  end if;

  if res = 'created' then
    perform public.harpatka_notify_signup(nm, n, p_age, md, mt, pid, mid, p_gender);
  end if;
  return res;
end $$;
revoke all on function public.harpatka_signup(text, text, int, text, text) from public;
grant execute on function public.harpatka_signup(text, text, int, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
