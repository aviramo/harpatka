-- הרשמה למפגש שנבחר (לא רק הקרוב): פרמטר p_meeting אופציונלי ל-harpatka_signup. אידמפוטנטי; להריץ על public, ואז admin/test-site.sql (מעתיק את הפונקציה ל-test).
-- אסימון חיבור חד פעמי: ההרשמה מהאתר שומרת אסימון (שנוצר בדפדפן) על המשתתף החדש, ובכניסה עם גוגל באזור האישי (harpatka_me_claim_token) המשתתף מתחבר לחשבון בלי להזין טלפון שוב
alter table public.harpatka_participants add column if not exists claim_token uuid;
alter table public.harpatka_participants add column if not exists claim_token_at timestamptz;
alter table test.harpatka_participants add column if not exists claim_token uuid;
alter table test.harpatka_participants add column if not exists claim_token_at timestamptz;
drop function if exists public.harpatka_signup(text, integer, text, text, text, text, text);
drop function if exists public.harpatka_signup(text, integer, text, text, text, text, text, uuid);
CREATE OR REPLACE FUNCTION public.harpatka_signup(p_phone text, p_age integer DEFAULT NULL::integer, p_gender text DEFAULT NULL::text, p_src text DEFAULT NULL::text, p_first text DEFAULT NULL::text, p_last text DEFAULT NULL::text, p_name text DEFAULT NULL::text, p_meeting uuid DEFAULT NULL::uuid, p_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  n   text := public.harpatka_normalize_phone(p_phone);
  fullname text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  fn  text; ln text; nm text;
  pid uuid; mid uuid; md date; mt time; act boolean; stored text;
  res text := 'created'; linked int := 0; react boolean := false; base text; tail text;
begin
  perform set_config('harpatka.skip_note', '1', true);   -- הרשמה מהטופס = הערת מערכת אחת (נכתבת בסוף), בלי הערות של הטריגרים
  if p_first is not null or p_last is not null then
    fn := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g')); ln := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
  else
    fn := split_part(fullname, ' ', 1); ln := btrim(substr(fullname, length(fn) + 1));
  end if;
  nm := btrim(fn || ' ' || ln);
  if char_length(fn) < 2 or char_length(ln) < 2 or char_length(fn) > 40 or char_length(ln) > 40 or char_length(nm) > 60 then return 'invalid_name'; end if;
  if n = '' then return 'invalid_phone'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is null or p_gender not in ('male', 'female') then return 'invalid_gender'; end if;   -- מגדר, גיל, שם פרטי ושם משפחה וטלפון: שדות חובה

  -- מפגש שנבחר (p_meeting): אם הוא קיים ועוד לא עבר, ההרשמה אליו; אחרת למפגש הקרוב
  if p_meeting is not null then
    select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
      where id = p_meeting and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;
  end if;
  if mid is null then
    select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
      where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date
      order by meeting_date, meeting_time limit 1;
  end if;

  select id, active, name into pid, act, stored from public.harpatka_participants where phone_norm = n limit 1;
  if pid is not null and coalesce(stored, '') <> '' then nm := stored; end if;   -- משתתף קיים: השם המלא שלו מהמערכת (לא מאפסים את nm כשלא נמצא)
  if pid is not null then
    -- הטלפון הוא המפתח: משתתף קיים לא מתעדכן. משתתף לא פעיל (הוסר) חוזר להיות פעיל, בלי שינוי בשאר השדות
    if act then res := 'exists';
    else update public.harpatka_participants set active = true where id = pid; res := 'created'; react := true; end if;
  else
    begin
      insert into public.harpatka_participants (first_name, last_name, phone, age, age_set_at, source, gender, claim_token, claim_token_at)
        values (fn, ln, n, p_age, current_date, case when p_src = 'p' then 'site-ad' else 'site' end, p_gender, p_token, case when p_token is not null then now() end)
        returning id into pid;
    exception when unique_violation then
      select id into pid from public.harpatka_participants where phone_norm = n limit 1;
      res := 'exists';
    end;
  end if;

  if mid is not null and pid is not null then
    insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false)
      on conflict (participant_id, meeting_id) do nothing;
    get diagnostics linked = row_count;
  end if;
  if pid is not null then
    base := case when res = 'exists' then 'נרשם/ה שוב דרך האתר' when react then 'חזר/ה להיות פעיל/ה בהרשמה חדשה דרך האתר'
                 else 'נרשם/ה דרך האתר' || case when p_src = 'p' then ' (ממומן)' else '' end end;
    tail := case when mid is null then ' (אין מפגש קרוב)' when linked > 0 then ' ושויך/ה למפגש ' || public.harpatka_meeting_label(mid)
                 else ' (כבר משויך/ת למפגש ' || public.harpatka_meeting_label(mid) || ')' end;
    perform public.harpatka_sys_note(pid, base || tail || ' · טלפון ' || n, case when res = 'exists' then 'reregistered' when react then 'reactivated' else 'registered' end, mid, null, null, null, case when p_src = 'p' then 'site-ad' else 'site' end);
  end if;

  if res = 'created' then
    perform public.harpatka_notify_signup(nm, n, p_age, md, mt, pid, mid, p_gender);
  end if;
  return res;
end $function$
;
grant execute on function public.harpatka_signup(text, integer, text, text, text, text, text, uuid, uuid) to anon, authenticated;

-- סביבת הבדיקות: מסירים את הגרסה הישנה לפני העתקה מחדש (למנוע עמימות בין שתי גרסאות)
drop function if exists test.harpatka_signup(text, integer, text, text, text, text, text);
drop function if exists test.harpatka_signup(text, integer, text, text, text, text, text, uuid);
