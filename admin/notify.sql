-- ==========================================================================
-- התראת מייל על כל הרשמה חדשה מהטופס באתר (מייל אחד, שני נמענים: אופיר והדר)
--
-- להריץ ב-SQL Editor של Supabase (אחרי setup.sql), פעם אחת; אפשר להריץ שוב בלי נזק.
-- המייל נשלח רק כשנוצר משתתף חדש (לא על כפילות של אותו טלפון), דרך Google Apps Script
-- (admin/notify-apps-script.gs), בלי שירות חיצוני ובלי דומיין.
--
-- אחרי ההרצה: להכניס את כתובת ה-Web App והטוקן (ראו בסוף הקובץ).
-- אם ההתראה נכשלת, ההרשמה עצמה לא נפגעת.
-- ==========================================================================

create extension if not exists pg_net;

create table if not exists public.harpatka_settings (key text primary key, value text not null default '');
alter table public.harpatka_settings enable row level security;          -- בלי מדיניות: רק פונקציות security definer קוראות
revoke all on public.harpatka_settings from anon, authenticated;

create or replace function public.harpatka_notify_signup(p_name text, p_phone text, p_age int, p_mdate date, p_mtime time)
returns void language plpgsql security definer set search_path = public as $$
declare u text; tok text;
begin
  select value into u   from public.harpatka_settings where key = 'notify_url';
  select value into tok from public.harpatka_settings where key = 'notify_token';
  if coalesce(u, '') = '' then return; end if;
  perform net.http_post(
    url     := u,
    body    := jsonb_build_object('token', tok, 'name', p_name, 'phone', p_phone, 'age', p_age,
                                  'meeting_date', p_mdate, 'meeting_time', to_char(p_mtime, 'HH24:MI'), 'created_at', now()),
    headers := jsonb_build_object('Content-Type', 'application/json')
  );
exception when others then
  null;   -- התראה שנכשלה לא מפילה את ההרשמה
end $$;
revoke all on function public.harpatka_notify_signup(text, text, int, date, time) from public, anon, authenticated;

-- הרשמה מהאתר (כמו ב-setup.sql) + התראה על משתתף חדש בלבד
drop function if exists public.harpatka_signup(text, text, int);
create or replace function public.harpatka_signup(p_name text, p_phone text, p_age int default null)
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

  select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
    where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
    order by meeting_date, meeting_time limit 1;

  select id into pid from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null then
    res := 'exists';
    update public.harpatka_participants set age = p_age, age_set_at = current_date where id = pid and age is null;
  else
    begin
      insert into public.harpatka_participants (name, phone, age, age_set_at, source)
        values (nm, n, p_age, current_date, 'site')
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
    perform public.harpatka_notify_signup(nm, n, p_age, md, mt);
  end if;
  return res;
end $$;
revoke all on function public.harpatka_signup(text, text, int) from public;
grant execute on function public.harpatka_signup(text, text, int) to anon, authenticated;

notify pgrst, 'reload schema';

-- ==========================================================================
-- אחרי שפרסמת את ה-Apps Script (admin/notify-apps-script.gs): להריץ שורה אחת (עם הערכים שלך):
--
--   insert into public.harpatka_settings (key, value) values
--     ('notify_url',   'https://script.google.com/macros/s/XXXXXXXX/exec'),
--     ('notify_token', 'סיסמה-אקראית-ארוכה')
--   on conflict (key) do update set value = excluded.value;
--
-- הטוקן חייב להיות זהה ל-NOTIFY_TOKEN ב-Script Properties של ה-Apps Script.
-- לכיבוי ההתראות: delete from public.harpatka_settings where key = 'notify_url';
-- ==========================================================================
