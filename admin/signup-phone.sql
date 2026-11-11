-- שלב הטלפון לאורח (11.11.26): הרשמה בשני שלבים בלי חשבון גוגל.
-- harpatka_signup_phone(p_phone, p_meeting, p_src, p_token): מחזירה json
--   משתתף קיים עם פרטים מלאים: נרשם למפגש בלי למלא פרטים (status = created / exists, ועם age לבדיקת טווח התשלום).
--   אחרת (טלפון חדש או משתתף בלי פרטים): כבר בשלב הזה נוצר משתתף עם הטלפון בלבד (אם אין) ונרשם למפגש, ו-status = need_details.
--   האסימון p_token נשמר על המשתתף וממנו משלימים פרטים ב-harpatka_signup_complete.
--   invalid_phone: טלפון לא תקין. חושפת למי שמנסה מספר אם הוא רשום (פשרה מודעת).
create or replace function __S__.harpatka_signup_phone(p_phone text, p_meeting uuid default null, p_src text default null, p_token uuid default null)
returns jsonb language plpgsql security definer set search_path = __S__, public as $$
declare
  n text; pa __S__.harpatka_participants; r text; pid uuid; created boolean := false; mid uuid; md date; linked int := 0;
  src text := case when p_src = 'p' then 'site-ad' else 'site' end;
begin
  n := __S__.harpatka_normalize_phone(p_phone);
  if n is null or n = '' then return jsonb_build_object('status', 'invalid_phone'); end if;
  select * into pa from __S__.harpatka_participants where phone_norm = n order by active desc, created_at limit 1;
  if found and coalesce(trim(pa.first_name), '') <> '' and coalesce(trim(pa.last_name), '') <> '' and pa.age is not null and coalesce(pa.gender, '') <> '' then
    r := __S__.harpatka_signup(p_phone => p_phone, p_age => pa.age, p_gender => pa.gender, p_src => p_src, p_first => pa.first_name, p_last => pa.last_name, p_meeting => p_meeting, p_token => null);
    return jsonb_build_object('status', r, 'age', pa.age);
  end if;
  perform set_config('harpatka.skip_note', '1', true);   -- הערת מערכת אחת בסוף
  pid := pa.id;
  if pid is null then
    begin
      insert into __S__.harpatka_participants (first_name, last_name, phone, phone_norm, age, age_set_at, source, gender, claim_token, claim_token_at)
        values ('', '', n, n, null, current_date, src, null, p_token, case when p_token is null then null else now() end) returning id into pid;
      created := true;
    exception when unique_violation then
      select id into pid from __S__.harpatka_participants where phone_norm = n limit 1;
    end;
  end if;
  if not created and p_token is not null then update __S__.harpatka_participants set claim_token = p_token, claim_token_at = now(), active = true where id = pid; end if;
  if p_meeting is not null then
    select id, meeting_date into mid, md from __S__.harpatka_meetings where id = p_meeting and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;
  end if;
  if mid is null then
    select id, meeting_date into mid, md from __S__.harpatka_meetings where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date order by meeting_date, meeting_time limit 1;
  end if;
  if mid is not null then
    insert into __S__.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false) on conflict (participant_id, meeting_id) do nothing;
    get diagnostics linked = row_count;
  end if;
  if created or linked > 0 then
    begin perform __S__.harpatka_sys_note(pid, case when created then 'נרשם/ה דרך האתר' || case when p_src = 'p' then ' (ממומן)' else '' end else 'נרשם/ה שוב דרך האתר' end
      || case when mid is null then ' (אין מפגש קרוב)' when linked > 0 then ' ושויך/ה למפגש ' || __S__.harpatka_meeting_label(mid) else '' end || ' · טלפון ' || n,
      case when created then 'registered' else 'reregistered' end, mid, null, null, null, src); exception when others then null; end;
  end if;
  return jsonb_build_object('status', 'need_details', 'registered', mid is not null);
end $$;
revoke all on function __S__.harpatka_signup_phone(text, uuid, text, uuid) from public;
grant execute on function __S__.harpatka_signup_phone(text, uuid, text, uuid) to anon, authenticated;

-- השלמת פרטים אחרי שלב הטלפון: האסימון הוא ההרשאה (תקף יומיים)
create or replace function __S__.harpatka_signup_complete(p_token uuid, p_first text, p_last text, p_age int, p_gender text)
returns text language plpgsql security definer set search_path = __S__, public as $$
declare pa __S__.harpatka_participants; fn text; ln text;
begin
  if p_token is null then return 'invalid_token'; end if;
  fn := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g')); ln := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
  if char_length(fn) < 2 then return 'invalid_name'; end if;
  if char_length(ln) < 2 then return 'invalid_name'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender not in ('male', 'female') then return 'invalid_gender'; end if;
  select * into pa from __S__.harpatka_participants where claim_token = p_token and claim_token_at > now() - interval '2 days';
  if not found then return 'invalid_token'; end if;
  perform set_config('harpatka.skip_note', '1', true);
  update __S__.harpatka_participants set first_name = fn, last_name = ln, age = p_age, age_set_at = current_date, gender = p_gender where id = pa.id;
  return 'ok';
end $$;
revoke all on function __S__.harpatka_signup_complete(uuid, text, text, int, text) from public;
grant execute on function __S__.harpatka_signup_complete(uuid, text, text, int, text) to anon, authenticated;
