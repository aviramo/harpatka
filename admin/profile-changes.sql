-- יומן שינויי ערכים של משתתף (29.10.26): כל שינוי בשם פרטי, שם משפחה, טלפון, גיל או מגדר של משתתף נרשם בהערות כהערה נפרדת (profile_changed) עם הערך הישן והערך החדש,
-- בלי קשר למי ביצע: המשתתף באזור האישי, מנהל בדף הניהול או מנהל בהתחזות. טריגר על הטבלה (לא בפונקציות).
-- בנוסף: הערת ההרשמה (נרשם/ה דרך האתר) שומרת את הטלפון שבו נרשם ("· טלפון +972...") כצילום מצב שלא משתנה גם כשהטלפון משתנה אחר כך;
-- הערות הרשמה קיימות קיבלו את הטלפון הנוכחי (הערך המקורי לא נשמר לפני כן). אידמפוטנטי; להריץ על public, ואז admin/test-site.sql.
create or replace function public.harpatka_participant_changes() returns trigger
language plpgsql security definer set search_path = public as $$
declare g text[] := array['male', 'female']; gl text[] := array['זכר', 'נקבה'];
begin
  begin
    if old.first_name is distinct from new.first_name then perform public.harpatka_sys_note(new.id, 'שם פרטי: ' || coalesce(old.first_name, '') || ' ← ' || coalesce(new.first_name, ''), 'profile_changed'); end if;
    if old.last_name is distinct from new.last_name then perform public.harpatka_sys_note(new.id, 'שם משפחה: ' || coalesce(old.last_name, '') || ' ← ' || coalesce(new.last_name, ''), 'profile_changed'); end if;
    if old.phone_norm is distinct from new.phone_norm then perform public.harpatka_sys_note(new.id, 'טלפון: ' || coalesce(nullif(old.phone_norm, ''), old.phone, '') || ' ← ' || coalesce(nullif(new.phone_norm, ''), new.phone, ''), 'profile_changed'); end if;
    if old.age is distinct from new.age then perform public.harpatka_sys_note(new.id, 'גיל: ' || coalesce(old.age::text, '') || ' ← ' || coalesce(new.age::text, ''), 'profile_changed'); end if;
    if old.gender is distinct from new.gender then perform public.harpatka_sys_note(new.id, 'מגדר: ' || coalesce(gl[array_position(g, old.gender)], '') || ' ← ' || coalesce(gl[array_position(g, new.gender)], ''), 'profile_changed'); end if;
  exception when others then null;   -- כשל בהערה לא מבטל את השמירה
  end;
  return new;
end $$;
revoke all on function public.harpatka_participant_changes() from public, anon, authenticated;
drop trigger if exists harpatka_participant_changes on public.harpatka_participants;
create trigger harpatka_participant_changes after update of first_name, last_name, phone_norm, age, gender on public.harpatka_participants
  for each row execute function public.harpatka_participant_changes();

-- הערות הרשמה קיימות: צילום הטלפון (הערך הנוכחי, כי הקודם לא נשמר)
update public.harpatka_notes n set body = n.body || ' · טלפון ' || p.phone_norm
  from public.harpatka_participants p
  where p.id = n.participant_id and n.system and n.event_type in ('registered', 'reregistered', 'reactivated') and n.body not like '%· טלפון %' and coalesce(p.phone_norm, '') <> '';
update test.harpatka_notes n set body = n.body || ' · טלפון ' || p.phone_norm
  from test.harpatka_participants p
  where p.id = n.participant_id and n.system and n.event_type in ('registered', 'reregistered', 'reactivated') and n.body not like '%· טלפון %' and coalesce(p.phone_norm, '') <> '';
