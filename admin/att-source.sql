-- דרך ההגעה לכל הרשמה למפגש (3.11.26). עד עכשיו דרך ההגעה נשמרה רק על המשתתף, ולכן מי שהגיע פעם מפייסבוק נצבע כך בכל מפגש.
-- עכשיו לכל שיוך משתתף-מפגש עמודה source_promoter_id: איך הוא הגיע למפגש הזה.
-- הכלל: ההרשמה הראשונה של משתתף מקבלת את דרך ההגעה שלו. הרשמה נוספת נקבעת לפי הקישור שממנו נרשם (?s=), ובלעדיו נשארת בלי דרך הגעה.
-- תוספת בלבד: הקוד הישן מתעלם מהעמודה. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/att-source.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/att-source.sql | supabase db query --linked
alter table __S__.harpatka_attendance add column if not exists source_promoter_id uuid references __S__.harpatka_promoters(id) on delete set null;

-- דרך ההגעה הכללית של משתתף: אותו חישוב כמו channelOf בדף הניהול (בחירה, אחרת הקוד בקישור)
create or replace function __S__.harpatka_channel_of(p_pid uuid) returns uuid language sql stable set search_path = __S__, public as $$
  select coalesce(
    (select pr.id from __S__.harpatka_promoters pr where pr.id = p.promoter_id),
    (select pr.id from __S__.harpatka_promoters pr where pr.code = coalesce(p.source_code, case when p.source = 'site-ad' then 'p' end) limit 1))
  from __S__.harpatka_participants p where p.id = p_pid
$$;

-- שיוך חדש: קודם הקישור שממנו נרשם (harpatka.src, נקבע בפונקציות ההרשמה), ואם זו ההרשמה הראשונה של המשתתף, דרך ההגעה שלו
create or replace function __S__.harpatka_att_source() returns trigger language plpgsql security definer set search_path = __S__, public as $$
declare c text := nullif(current_setting('harpatka.src', true), '');
begin
  if new.source_promoter_id is not null then return new; end if;
  if c is not null then select id into new.source_promoter_id from __S__.harpatka_promoters where code = c limit 1; end if;
  if new.source_promoter_id is null and not exists (select 1 from __S__.harpatka_attendance where participant_id = new.participant_id) then
    new.source_promoter_id := __S__.harpatka_channel_of(new.participant_id);
  end if;
  return new;
end $$;
drop trigger if exists harpatka_att_source on __S__.harpatka_attendance;
create trigger harpatka_att_source before insert on __S__.harpatka_attendance for each row execute function __S__.harpatka_att_source();

-- שינוי "מקור" של משתתף: מתעדכנת רק ההרשמה הראשונה שלו
create or replace function __S__.harpatka_participant_source_sync() returns trigger language plpgsql security definer set search_path = __S__, public as $$
begin
  update __S__.harpatka_attendance a set source_promoter_id = __S__.harpatka_channel_of(new.id)
    where a.participant_id = new.id and a.meeting_id = (select a2.meeting_id from __S__.harpatka_attendance a2 where a2.participant_id = new.id order by a2.created_at, a2.meeting_id limit 1);
  return new;
end $$;
drop trigger if exists harpatka_participant_source_sync on __S__.harpatka_participants;
create trigger harpatka_participant_source_sync after update of promoter_id, source, source_code on __S__.harpatka_participants for each row
  when (old.promoter_id is distinct from new.promoter_id or old.source is distinct from new.source or old.source_code is distinct from new.source_code)
  execute function __S__.harpatka_participant_source_sync();

-- הרשמה קיימת: ההרשמה הראשונה של כל משתתף מקבלת את דרך ההגעה שלו, והאחרות נשארות בלי
update __S__.harpatka_attendance a set source_promoter_id = __S__.harpatka_channel_of(a.participant_id)
  where a.source_promoter_id is null
    and not exists (select 1 from __S__.harpatka_attendance b where b.participant_id = a.participant_id and (b.created_at, b.meeting_id) < (a.created_at, a.meeting_id));

-- פונקציות ההרשמה: הקישור שממנו נרשמו (p_src) עובר לטריגר
do $do$
declare r record; d text;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname in ('harpatka_signup', 'harpatka_me_phone', 'harpatka_me_join') loop
    d := pg_get_functiondef(r.oid);
    if d like '%p_src%' and d not like '%harpatka.src%' then
      d := regexp_replace(d, E'(\\nbegin[ \\t]*\\n)', E'\\1  if p_src is not null then perform set_config(''harpatka.src'', p_src, true); end if;\n', 'i');
      if d not like '%harpatka.src%' then raise exception 'לא נמצא begin בפונקציה %', r.oid; end if;
      execute d;
    end if;
  end loop;
end $do$;

-- הרשמה בלחיצה של משתתף מחובר, עם הקישור שממנו הגיע (עטיפה, כדי לא לשנות את החתימה של harpatka_me_register)
do $do$
declare ret text;
begin
  select pg_get_function_result(p.oid) into ret from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_me_register' limit 1;
  drop function if exists __S__.harpatka_me_register_src(uuid, text, uuid);
  execute format($f$create function __S__.harpatka_me_register_src(p_meeting uuid, p_src text default null, p_as uuid default null) returns %s language plpgsql set search_path = __S__, public as $b$
begin
  if p_src is not null then perform set_config('harpatka.src', p_src, true); end if;
  return __S__.harpatka_me_register(p_meeting, p_as);
end $b$$f$, ret);
end $do$;
revoke all on function __S__.harpatka_me_register_src(uuid, text, uuid) from public, anon;
grant execute on function __S__.harpatka_me_register_src(uuid, text, uuid) to authenticated;
