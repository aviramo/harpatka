-- מפגש יורש את ברירות המחדל של סוג המפגש (31.10.26). שדה שלא מולא במפגש = "כמו בסוג":
--   harpatka_meetings.inherit = רשימת השדות שהמפגש לוקח מהסוג (name, meeting_time, city, max_participants, directions, price_tiers, image_url).
--   הערכים עצמם נשמרים בעמודות המפגש (כך שעמוד הבית, האזור האישי, המיילים והפונקציות ממשיכים לקרוא אותם כרגיל):
--   (1) לפני כל שמירה של מפגש: כל שדה ב-inherit מקבל את הערך של הסוג שלו;
--   (2) שינוי בברירות המחדל של סוג מעדכן את המפגשים העתידיים מאותו סוג בשדות שהם יורשים (מפגשים שעברו לא משתנים).
-- אידמפוטנטי. בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_.

alter table public.harpatka_meetings add column if not exists inherit text[] not null default '{}';

create or replace function public.harpatka_meeting_inherit() returns trigger
language plpgsql as $fn$
declare t public.harpatka_meeting_types%rowtype;
begin
  if new.type_id is null or coalesce(cardinality(new.inherit), 0) = 0 then return new; end if;
  select * into t from public.harpatka_meeting_types where id = new.type_id;
  if t.id is null then return new; end if;
  if 'name' = any(new.inherit) then new.name := nullif(btrim(coalesce(t.name, '')), ''); end if;
  if 'meeting_time' = any(new.inherit) then new.meeting_time := coalesce(t.meeting_time, new.meeting_time, '20:00'); end if;
  if 'city' = any(new.inherit) then new.city := t.city; end if;
  if 'max_participants' = any(new.inherit) then new.max_participants := t.max_participants; end if;
  if 'directions' = any(new.inherit) then new.directions := coalesce(t.directions, ''); end if;
  if 'price_tiers' = any(new.inherit) then new.price_tiers := t.price_tiers; end if;
  if 'image_url' = any(new.inherit) then new.image_url := t.image_url; end if;
  return new;
end $fn$;
drop trigger if exists harpatka_meeting_inherit on public.harpatka_meetings;
create trigger harpatka_meeting_inherit before insert or update on public.harpatka_meetings
  for each row execute function public.harpatka_meeting_inherit();

-- שינוי בסוג: המפגשים העתידיים שיורשים מתעדכנים (העדכון מפעיל את הטריגר שלמעלה)
create or replace function public.harpatka_type_propagate() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
begin
  if (new.name, new.meeting_time, new.city, new.max_participants, new.directions, new.price_tiers::text, new.image_url)
     is not distinct from (old.name, old.meeting_time, old.city, old.max_participants, old.directions, old.price_tiers::text, old.image_url) then return new; end if;
  update public.harpatka_meetings set inherit = inherit
   where type_id = new.id and cardinality(inherit) > 0 and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;
  return new;
end $fn$;
drop trigger if exists harpatka_type_propagate on public.harpatka_meeting_types;
create trigger harpatka_type_propagate after update on public.harpatka_meeting_types
  for each row execute function public.harpatka_type_propagate();

-- מפגשים קיימים: כל שדה שזהה לערך של הסוג נחשב "כמו בסוג" (פעם אחת, רק כשעוד לא סומן)
update public.harpatka_meetings m set inherit = array_remove(array[
    case when nullif(btrim(coalesce(m.name, '')), '') is not distinct from nullif(btrim(coalesce(t.name, '')), '') then 'name' end,
    case when m.meeting_time is not distinct from t.meeting_time then 'meeting_time' end,
    case when m.city is not distinct from t.city then 'city' end,
    case when m.max_participants is not distinct from t.max_participants then 'max_participants' end,
    case when coalesce(m.directions, '') = coalesce(t.directions, '') then 'directions' end,
    case when m.price_tiers is not distinct from t.price_tiers then 'price_tiers' end,
    case when m.image_url is not distinct from t.image_url then 'image_url' end
  ]::text[], null)
  from public.harpatka_meeting_types t
 where t.id = m.type_id and cardinality(m.inherit) = 0;

notify pgrst, 'reload schema';
