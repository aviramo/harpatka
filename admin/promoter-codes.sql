-- כמה קודים לכל שיווק ממומן (8.11.26): כל שיווק ממומן יכול לקבל כמה קודים בקישור (?s=a, ?s=b ...), כדי שהאתר יוכל להיראות אחרת בכל אחד מהם.
-- העמודה החדשה codes (מערך). הקוד הישן code נשאר = הקוד הראשון (מתעדכן אוטומטית), כך שקוד ישן שקורא אותו ממשיך לעבוד.
-- אותו קוד לא יכול להיות בשתי דרכי הגעה (נבדק בטריגר). אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/promoter-codes.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/promoter-codes.sql | supabase db query --linked
alter table __S__.harpatka_promoters add column if not exists codes text[] not null default '{}';
update __S__.harpatka_promoters set codes = array[code] where code is not null and cardinality(codes) = 0;

create or replace function __S__.harpatka_promoter_codes_fn() returns trigger language plpgsql set search_path = __S__, public as $$
begin
  if tg_op = 'UPDATE' and new.codes is not distinct from old.codes and new.code is distinct from old.code then
    -- עדכון ישן שכתב רק code: הוא הופך לקוד הראשון
    new.codes := case when new.code is null then new.codes[2:] else array[new.code] || array_remove(new.codes, new.code) end;
  end if;
  new.codes := coalesce((select array_agg(c order by o) from (select c, min(o) o from unnest(new.codes) with ordinality u(c, o) where nullif(c, '') is not null group by c) z), '{}');
  new.code := new.codes[1];
  if exists (select 1 from __S__.harpatka_promoters p where p.id is distinct from new.id and p.codes && new.codes) then
    raise exception 'promoter_code_taken';
  end if;
  return new;
end $$;
drop trigger if exists harpatka_promoter_codes on __S__.harpatka_promoters;
create trigger harpatka_promoter_codes before insert or update of code, codes on __S__.harpatka_promoters for each row execute function __S__.harpatka_promoter_codes_fn();

-- חיפוש לפי קוד: כל אחד מהקודים של דרך ההגעה
create or replace function __S__.harpatka_channel_of(p_pid uuid) returns uuid language sql stable set search_path = __S__, public as $$
  select coalesce(
    (select pr.id from __S__.harpatka_promoters pr where pr.id = p.promoter_id),
    (select pr.id from __S__.harpatka_promoters pr where coalesce(p.source_code, case when p.source = 'site-ad' then 'p' end) = any(pr.codes) limit 1))
  from __S__.harpatka_participants p where p.id = p_pid
$$;

do $do$
declare d text; r record;
begin
  -- טריגר השיוך: הקישור שממנו נרשם (harpatka.src) מזהה את דרך ההגעה לפי כל אחד מהקודים
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.pronamespace = '__S__'::regnamespace and p.proname = 'harpatka_att_source';
  if d like '%where code = c limit 1%' then
    execute replace(d, 'where code = c limit 1', 'where c = any(codes) limit 1');
  end if;
end $do$;

-- מחיקת שיווק ממומן עם העברה: כל הקודים של המקורית עוברים ליעד, והמשתתפים שנרשמו עם קוד שלה מקושרים אליו
create or replace function __S__.harpatka_promoter_replace(p_from uuid, p_to uuid default null)
returns text language plpgsql set search_path = __S__, public as $$
declare f __S__.harpatka_promoters; t __S__.harpatka_promoters;
begin
  select * into f from __S__.harpatka_promoters where id = p_from;
  if not found then return 'not_found'; end if;
  if p_to is null then
    if exists (select 1 from __S__.harpatka_participants where promoter_id = p_from or source_code = any(f.codes) or ('p' = any(f.codes) and source = 'site-ad' and source_code is null and promoter_id is null))
      or exists (select 1 from __S__.harpatka_attendance where promoter_id = p_from or source_promoter_id = p_from)
      or exists (select 1 from __S__.harpatka_payments where promoter_id = p_from)
      or exists (select 1 from __S__.harpatka_promoter_payments where promoter_id = p_from) then
      return 'has_links';
    end if;
  else
    if p_to = p_from then return 'same'; end if;
    select * into t from __S__.harpatka_promoters where id = p_to;
    if not found then return 'no_target'; end if;
    update __S__.harpatka_participants
      set promoter_id = p_to
      where promoter_id = p_from or source_code = any(f.codes) or ('p' = any(f.codes) and source = 'site-ad' and source_code is null and promoter_id is null);
    update __S__.harpatka_attendance set promoter_id = p_to where promoter_id = p_from;
    update __S__.harpatka_attendance set source_promoter_id = p_to where source_promoter_id = p_from;
    update __S__.harpatka_payments set promoter_id = p_to where promoter_id = p_from;
    update __S__.harpatka_promoter_payments set promoter_id = p_to where promoter_id = p_from;
  end if;
  delete from __S__.harpatka_promoters where id = p_from;
  if p_to is not null and cardinality(f.codes) > 0 then
    update __S__.harpatka_promoters set codes = codes || f.codes where id = p_to;   -- הקודים של המקורית ממשיכים להוביל ליעד
  end if;
  return 'ok';
end $$;
revoke all on function __S__.harpatka_promoter_replace(uuid, uuid) from public, anon;
grant execute on function __S__.harpatka_promoter_replace(uuid, uuid) to authenticated;

-- סדר ידני של שיווק ממומן (גרירה, כמו תגיות): עמודה sort. בהתחלה לפי השם, כמו שהוצגו עד עכשיו
alter table __S__.harpatka_promoters add column if not exists sort int;
update __S__.harpatka_promoters p set sort = r.rn from (select id, row_number() over (order by name) rn from __S__.harpatka_promoters) r where r.id = p.id and p.sort is null;
