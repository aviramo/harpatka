-- ==========================================================================
-- הרשמה עם גוגל, קודם טלפון ואחר כך פרטים (31.10.26).
-- אחרי הכניסה עם גוגל, חשבון בלי משתתף מקושר מזין רק טלפון (harpatka_me_phone):
--   * טלפון של משתתף שכבר מחובר לחשבון גוגל אחר (מאושר או חסום): phone_taken, ומייל phone_conflict למנהלים.
--   * טלפון של משתתף קיים שלא מחובר: החשבון מתחבר אליו (לא פעיל חוזר להיות פעיל), בלי שינוי בפרטים שלו.
--   * טלפון שלא קיים: נוצר משתתף עם הטלפון בלבד ופרטים ריקים (שם פרטי ומשפחה ריקים, בלי גיל ומגדר).
--   ההרשמה למפגש שנבחר (או הקרוב) מתבצעת כבר כאן, לפני הפרטים. מחזירה { status, complete }.
-- אחר כך, אם חסרים פרטים, הפופאפ מבקש שם פרטי, שם משפחה, גיל ומגדר (harpatka_me_complete): הערת מערכת אחת "השלים/ה פרטים".
-- יומן שינויי הערכים (harpatka_participant_changes) לא רושם השלמה של שדה ריק כ"שינוי", ומכבד את harpatka.skip_note.
-- נכתב ל-public; בבדיקות מורץ אחרי החלפת public.harpatka_ ב-test.harpatka_ (search_path ל-test, public; harpatka_is_admin ל-harpatka_is_admin_site).
-- ==========================================================================

create or replace function public.harpatka_participant_changes() returns trigger
language plpgsql security definer set search_path = public as $$
declare g text[] := array['male', 'female']; gl text[] := array['זכר', 'נקבה'];
begin
  if current_setting('harpatka.skip_note', true) = '1' then return new; end if;   -- פעולה שכותבת הערה משלה (למשל השלמת פרטים)
  begin   -- השלמה של שדה ריק (בלי ערך קודם) היא לא שינוי
    if coalesce(old.first_name, '') <> '' and old.first_name is distinct from new.first_name then perform public.harpatka_sys_note(new.id, 'שם פרטי: ' || coalesce(old.first_name, '') || ' ← ' || coalesce(new.first_name, ''), 'profile_changed'); end if;
    if coalesce(old.last_name, '') <> '' and old.last_name is distinct from new.last_name then perform public.harpatka_sys_note(new.id, 'שם משפחה: ' || coalesce(old.last_name, '') || ' ← ' || coalesce(new.last_name, ''), 'profile_changed'); end if;
    if coalesce(old.phone_norm, old.phone, '') <> '' and old.phone_norm is distinct from new.phone_norm then perform public.harpatka_sys_note(new.id, 'טלפון: ' || coalesce(nullif(old.phone_norm, ''), old.phone, '') || ' ← ' || coalesce(nullif(new.phone_norm, ''), new.phone, ''), 'profile_changed'); end if;
    if old.age is not null and old.age is distinct from new.age then perform public.harpatka_sys_note(new.id, 'גיל: ' || coalesce(old.age::text, '') || ' ← ' || coalesce(new.age::text, ''), 'profile_changed'); end if;
    if old.gender is not null and old.gender is distinct from new.gender then perform public.harpatka_sys_note(new.id, 'מגדר: ' || coalesce(gl[array_position(g, old.gender)], '') || ' ← ' || coalesce(gl[array_position(g, new.gender)], ''), 'profile_changed'); end if;
  exception when others then null;   -- כשל בהערה לא מבטל את השמירה
  end;
  return new;
end $$;
revoke all on function public.harpatka_participant_changes() from public, anon, authenticated;

create or replace function public.harpatka_me_phone(p_phone text, p_meeting uuid default null, p_src text default null, p_no_meeting boolean default false)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  uid uuid := auth.uid();
  norm text := public.harpatka_normalize_phone(p_phone);
  em text := lower(coalesce(auth.jwt() ->> 'email', ''));
  gname text := coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name', '');
  src text := case when p_src = 'p' then 'site-ad' else 'site' end;
  m public.harpatka_members; pid uuid; act boolean; created boolean := false; react boolean := false;
  mid uuid; md date; mt time; linked int := 0; pa public.harpatka_participants; base text; tail text; disp text;
begin
  if uid is null then raise exception 'auth'; end if;
  select * into m from public.harpatka_members where user_id = uid;
  if m.user_id is not null and m.status = 'blocked' then return jsonb_build_object('status', 'blocked'); end if;
  if coalesce(norm, '') = '' then return jsonb_build_object('status', 'invalid_phone'); end if;
  disp := case when norm like '+972%' then '0' || substr(norm, 5) else norm end;

  -- טלפון של משתתף שכבר מחובר לחשבון גוגל אחר: לא מחברים ולא נרשמים, ומודיעים למנהלים
  select id, active into pid, act from public.harpatka_participants where phone_norm = norm order by active desc, created_at limit 1;
  if pid is not null and exists (select 1 from public.harpatka_members x where x.participant_id = pid and x.user_id <> uid and x.status in ('approved', 'blocked')) then
    perform public.harpatka_notify_phone_conflict(coalesce(nullif(gname, ''), disp), norm, null, null, em,
      case when coalesce(p_no_meeting, false) then null else p_meeting end, pid, p_no_meeting);
    return jsonb_build_object('status', 'phone_taken');
  end if;

  perform set_config('harpatka.skip_note', '1', true);   -- הערת מערכת אחת בסוף, בלי הערות של הטריגרים
  if pid is null then   -- משתתף חדש: הטלפון בלבד, הפרטים ריקים עד ההשלמה
    begin
      insert into public.harpatka_participants (first_name, last_name, phone, phone_norm, age, age_set_at, source, gender)
        values ('', '', norm, norm, null, current_date, src, null) returning id into pid;
      created := true;
    exception when unique_violation then
      select id, active into pid, act from public.harpatka_participants where phone_norm = norm limit 1;
    end;
  end if;
  if not created and not coalesce(act, true) then update public.harpatka_participants set active = true where id = pid; react := true; end if;

  -- ההרשמה למפגש כבר עכשיו, לפני הפרטים: המפגש שנבחר אם עוד לא עבר, אחרת הקרוב
  if not coalesce(p_no_meeting, false) then
    if p_meeting is not null then
      select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
        where id = p_meeting and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;
    end if;
    if mid is null then
      select id, meeting_date, meeting_time into mid, md, mt from public.harpatka_meetings
        where meeting_date >= (now() at time zone 'Asia/Jerusalem')::date order by meeting_date, meeting_time limit 1;
    end if;
    if mid is not null then
      insert into public.harpatka_attendance (participant_id, meeting_id, paid) values (pid, mid, false) on conflict (participant_id, meeting_id) do nothing;
      get diagnostics linked = row_count;
    end if;
  end if;

  if created or react or linked > 0 then
    base := case when created then 'נרשם/ה דרך האתר עם חשבון גוגל' || case when p_src = 'p' then ' (ממומן)' else '' end
                 when react then 'חזר/ה להיות פעיל/ה בהרשמה דרך האתר' else 'נרשם/ה שוב דרך האתר' end;
    tail := case when mid is null then case when coalesce(p_no_meeting, false) then ' (בלי שיוך למפגש)' else ' (אין מפגש קרוב)' end
                 when linked > 0 then ' ושויך/ה למפגש ' || public.harpatka_meeting_label(mid)
                 else ' (כבר משויך/ת למפגש ' || public.harpatka_meeting_label(mid) || ')' end;
    perform public.harpatka_sys_note(pid, base || tail || ' · טלפון ' || norm, case when created then 'registered' when react then 'reactivated' else 'reregistered' end, mid, null, null, null, src);
  end if;
  if created or react then perform public.harpatka_notify_signup(disp, norm, null, md, mt, pid, mid, null); end if;   -- מייל "הרשמה חדשה" למנהלים (עוד בלי שם: הטלפון)

  -- חיבור חשבון הגוגל למשתתף (מאושר מיד)
  if m.user_id is not null then
    update public.harpatka_members set participant_id = pid, phone_norm = norm, status = 'approved', wants_me = true where user_id = uid;
  else
    insert into public.harpatka_members (user_id, email, google_name, phone_norm, participant_id, status, wants_me)
    values (uid, em, gname, norm, pid, 'approved', true);
  end if;

  select * into pa from public.harpatka_participants where id = pid;
  return jsonb_build_object('status', case when created then 'created' when react then 'reactivated' else 'linked' end,
    'complete', (char_length(btrim(pa.first_name)) >= 2 and char_length(btrim(pa.last_name)) >= 2 and pa.age is not null and pa.gender is not null));
end $$;
revoke all on function public.harpatka_me_phone(text, uuid, text, boolean) from public;
grant execute on function public.harpatka_me_phone(text, uuid, text, boolean) to authenticated;

create or replace function public.harpatka_me_complete(p_first text, p_last text, p_age int, p_gender text, p_as uuid default null)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  uid uuid := auth.uid(); m public.harpatka_members; pid uuid;
  fn text := btrim(regexp_replace(coalesce(p_first, ''), '\s+', ' ', 'g'));
  ln text := btrim(regexp_replace(coalesce(p_last, ''), '\s+', ' ', 'g'));
begin
  if uid is null then raise exception 'auth'; end if;
  if p_as is not null then
    if not public.harpatka_is_admin() then return 'forbidden'; end if;
    pid := p_as;
  else
    select * into m from public.harpatka_members where user_id = uid;
    if m.user_id is null or m.participant_id is null or m.status <> 'approved' then return 'none'; end if;
    pid := m.participant_id;
  end if;
  if char_length(fn) < 2 or char_length(ln) < 2 or char_length(fn) > 40 or char_length(ln) > 40 then return 'invalid_name'; end if;
  if p_age is null or p_age < 18 or p_age > 99 then return 'invalid_age'; end if;
  if p_gender is null or p_gender not in ('male', 'female') then return 'invalid_gender'; end if;
  perform set_config('harpatka.skip_note', '1', true);
  update public.harpatka_participants set first_name = fn, last_name = ln, age = p_age, age_set_at = current_date, gender = p_gender where id = pid;
  perform public.harpatka_sys_note(pid, 'השלים/ה פרטים: ' || fn || ' ' || ln || ' · גיל ' || p_age || ' · ' || case p_gender when 'male' then 'זכר' else 'נקבה' end, 'profile_completed');
  return 'ok';
end $$;
revoke all on function public.harpatka_me_complete(text, text, int, text, uuid) from public;
grant execute on function public.harpatka_me_complete(text, text, int, text, uuid) to authenticated;
