-- ==========================================================================
-- יוצאים להרפתקה: הרשמה מדף הבית (טופס שם + טלפון) + נרמול טלפונים וזיהוי כפילויות
--
-- להריץ פעם אחת, כולו, ב-Supabase של floa: SQL Editor -> New query -> להדביק -> Run.
-- אפשר להריץ שוב בלי נזק. (דורש ש-admin/schema.sql כבר הורץ.)
--
-- סטנדרט: כל מספר נשמר בפורמט בינלאומי E.164 ("+972501234567") בעמודה phone_norm.
-- מתקבלים: מספר ישראלי שמתחיל ב-0 (050-1234567 / 03-1234567), או מספר עם פלוס
-- וקידומת מדינה (+972..., +1..., 00972...). אחרת: לא תקין.
-- כפילות = אותו phone_norm. מספרים ישנים שלא עומדים בכלל נשארים phone_norm='' ולא נבדקים.
-- ==========================================================================

alter table public.harpatka_participants add column if not exists phone_norm text not null default '';
alter table public.harpatka_participants add column if not exists source     text not null default '';

-- 1. נרמול (אותה לוגיקה בדיוק כמו ב-index.html)
create or replace function public.harpatka_normalize_phone(p text)
returns text language plpgsql immutable as $$
declare
  raw  text := trim(coalesce(p, ''));
  plus boolean;
  d    text;
begin
  if raw = '' then return ''; end if;
  plus := left(raw, 1) = '+';
  d := regexp_replace(raw, '\D', '', 'g');
  if d = '' then return ''; end if;
  if left(d, 2) = '00' then plus := true; d := substr(d, 3); end if;          -- 00972...
  if plus then
    if left(d, 4) = '9720' then d := '972' || substr(d, 5); end if;           -- +972(0)50...
    if length(d) < 8 or length(d) > 15 or left(d, 1) = '0' then return ''; end if;
    if left(d, 3) = '972' and substr(d, 4) !~ '^(5\d{8}|7\d{8}|[23489]\d{7})$' then return ''; end if;
    return '+' || d;
  end if;
  if left(d, 1) = '0' then                                                     -- ישראלי מקומי
    if d ~ '^0(5\d{8}|7\d{8}|[23489]\d{7})$' then return '+972' || substr(d, 2); end if;
    return '';
  end if;
  return '';
end $$;

-- 2. כל הוספה/עדכון של טלפון (גם מדף הניהול) מנורמלים אוטומטית
create or replace function public.harpatka_participants_phone_trg()
returns trigger language plpgsql as $$
begin
  new.phone_norm := public.harpatka_normalize_phone(new.phone);
  return new;
end $$;

drop trigger if exists harpatka_participants_phone on public.harpatka_participants;
create trigger harpatka_participants_phone
  before insert or update of phone on public.harpatka_participants
  for each row execute function public.harpatka_participants_phone_trg();

-- 3. נרמול הרשומות הקיימות
update public.harpatka_participants set phone_norm = public.harpatka_normalize_phone(phone)
  where phone_norm is distinct from public.harpatka_normalize_phone(phone);

-- 4. אינדקס ייחודי למניעת כפילויות (נדלג עם הודעה אם כבר יש כפילויות קיימות: למזג ידנית ולהריץ שוב)
do $$
begin
  create unique index if not exists harpatka_participants_phone_norm_uq
    on public.harpatka_participants (phone_norm) where phone_norm <> '';
exception when unique_violation then
  raise notice 'יש כפילויות קיימות של מספרי טלפון: למזג אותן ידנית ולהריץ שוב כדי להפעיל את האינדקס הייחודי';
end $$;

-- 5. הרשמה מהאתר. מחזירה: created | exists | invalid_name | invalid_phone
--    המשתתף נקשר אוטומטית למפגש הקרוב (המפגש שמוצג בבאנר: התאריך הקרוב ביותר שעוד לא עבר, שעון ישראל)
--    כ"טרם שילם" (paid = false). אם המשתתף כבר קיים (אותו מספר) הוא נקשר למפגש הקרוב אם עוד לא היה מקושר.
create or replace function public.harpatka_signup(p_name text, p_phone text)
returns text language plpgsql security definer set search_path = public as $$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  nm  text := trim(coalesce(p_name, ''));
  pid uuid;
  mid uuid;
  res text := 'created';
begin
  if char_length(nm) < 2 or char_length(nm) > 60 then return 'invalid_name'; end if;
  if n = '' then return 'invalid_phone'; end if;

  select id into mid from public.harpatka_meetings
    where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
    order by meeting_date, meeting_time limit 1;

  select id into pid from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null then
    res := 'exists';
  else
    begin
      insert into public.harpatka_participants (name, phone, source) values (nm, n, 'site')   -- phone_norm נקבע בטריגר
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
  return res;
end $$;

revoke all on function public.harpatka_signup(text, text) from public;
grant execute on function public.harpatka_signup(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
