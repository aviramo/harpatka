-- שדה "מיקום" (שם המקום, למשל Guna House או המסילה) לסוג המפגש ולמפגש (31.10.26).
-- מפגש יורש אותו מהסוג כמו שאר השדות (harpatka_meetings.inherit כולל 'place'); בעמוד הבית מוצג אחרי העיר עם נקודה מפרידה.
-- אידמפוטנטי. בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_. בקידום: אחרי meeting-inherit.sql ו-meeting-types-public.sql.

alter table public.harpatka_meeting_types add column if not exists place text;
alter table public.harpatka_meetings add column if not exists place text;

create or replace function public.harpatka_meeting_inherit() returns trigger
language plpgsql as $fn$
declare t public.harpatka_meeting_types%rowtype;
begin
  if new.type_id is null or coalesce(cardinality(new.inherit), 0) = 0 then return new; end if;
  select * into t from public.harpatka_meeting_types where id = new.type_id;
  if t.id is null then return new; end if;
  if 'name' = any(new.inherit) then new.name := nullif(btrim(coalesce(t.name, '')), ''); end if;
  if 'meeting_time' = any(new.inherit) then new.meeting_time := coalesce(t.meeting_time, new.meeting_time, '20:00'); end if;
  if 'place' = any(new.inherit) then new.place := t.place; end if;
  if 'city' = any(new.inherit) then new.city := t.city; end if;
  if 'max_participants' = any(new.inherit) then new.max_participants := t.max_participants; end if;
  if 'directions' = any(new.inherit) then new.directions := coalesce(t.directions, ''); end if;
  if 'price_tiers' = any(new.inherit) then new.price_tiers := t.price_tiers; end if;
  if 'image_url' = any(new.inherit) then new.image_url := t.image_url; end if;
  return new;
end $fn$;

create or replace function public.harpatka_type_propagate() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
begin
  if (new.name, new.meeting_time, new.place, new.city, new.max_participants, new.directions, new.price_tiers::text, new.image_url)
     is not distinct from (old.name, old.meeting_time, old.place, old.city, old.max_participants, old.directions, old.price_tiers::text, old.image_url) then return new; end if;
  update public.harpatka_meetings set inherit = inherit
   where type_id = new.id and cardinality(inherit) > 0 and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;
  return new;
end $fn$;

-- מפגשים עתידיים מסוג כלשהו: המיקום נלקח מהסוג (מפגשים שעברו לא משתנים)
update public.harpatka_meetings set inherit = array_append(inherit, 'place')
 where type_id is not null and not ('place' = any(inherit)) and meeting_date >= (now() at time zone 'Asia/Jerusalem')::date;

-- האתר הציבורי קורא את המיקום של הסוג (meeting-types-public.sql)
grant select (place) on public.harpatka_meeting_types to anon;

notify pgrst, 'reload schema';
