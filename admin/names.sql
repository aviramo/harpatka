-- שם משתתף = שם פרטי + שם משפחה (שני שדות). העמודה name נשארת כשם מלא מחושב (first_name + ' ' + last_name), כך שכל מקום שמציג שם מלא ממשיך לעבוד.
-- הפיצול של השמות הקיימים: המילה הראשונה = שם פרטי, השאר = שם משפחה (שם בן מילה אחת: שם פרטי בלבד).
alter table public.harpatka_participants add column if not exists first_name text not null default '';
alter table public.harpatka_participants add column if not exists last_name  text not null default '';

do $$ begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'harpatka_participants' and column_name = 'name' and is_generated = 'NEVER') then
    update public.harpatka_participants set
      first_name = split_part(btrim(regexp_replace(name, '\s+', ' ', 'g')), ' ', 1),
      last_name  = btrim(substr(btrim(regexp_replace(name, '\s+', ' ', 'g')), length(split_part(btrim(regexp_replace(name, '\s+', ' ', 'g')), ' ', 1)) + 1))
      where first_name = '' and last_name = '';
    alter table public.harpatka_participants drop column name;
    alter table public.harpatka_participants add column name text generated always as (btrim(first_name || ' ' || last_name)) stored;
  end if;
end $$;

-- הרשמה מהאתר: שם פרטי + שם משפחה (p_first, p_last). p_name (שם מלא, לקוחות ישנים) מפוצל כמו לעיל.
drop function if exists public.harpatka_signup(text, text, int, text, text);
create or replace function public.harpatka_signup(p_phone text, p_age int default null, p_gender text default null, p_src text default null, p_first text default null, p_last text default null, p_name text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  fullname text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  fn  text; ln text; nm text;
  pid uuid; mid uuid; md date; mt time;
  res text := 'created';
begin
  if p_first is not null or p_last is not null then
    fn := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g')); ln := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
  else
    fn := split_part(fullname, ' ', 1); ln := btrim(substr(fullname, length(fn) + 1));
  end if;
  nm := btrim(fn || ' ' || ln);
  if char_length(fn) < 2 or char_length(fn) > 40 or char_length(ln) > 40 or char_length(nm) > 60 then return 'invalid_name'; end if;
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
      insert into public.harpatka_participants (first_name, last_name, phone, age, age_set_at, source, gender)
        values (fn, ln, n, p_age, current_date, case when p_src = 'p' then 'site-ad' else 'site' end, p_gender)
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
revoke all on function public.harpatka_signup(text, int, text, text, text, text, text) from public;
grant execute on function public.harpatka_signup(text, int, text, text, text, text, text) to anon, authenticated;
notify pgrst, 'reload schema';
