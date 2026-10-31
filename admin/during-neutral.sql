-- "הגיע" (שלב "במפגש") הוא סטטוס רגיל: אין משמעות לוגית מעבר לנראות ולציון התמדה (31.10.26).
-- 1) מבטלים את המראה ל-attended (העמודה נשארת כהיסטוריה, בלי שימוש).
-- 2) "הגיע" שייך לסוג הראשון כמו כל סטטוס רגיל.
-- 3) ביטול רישום באזור האישי כבר לא נחסם בגלל סימון הגעה (נשאר רק: מפגש שעבר).
-- הסקריפט אידמפוטנטי; להחליף __S__ ב-test או ב-public (sed 's/__S__/test/g').

drop trigger if exists harpatka_att_during_mirror on __S__.harpatka_attendance;
drop function if exists __S__.harpatka_att_during_mirror();

update __S__.harpatka_statuses
   set type_id = (select id from __S__.harpatka_meeting_types order by sort, created_at limit 1)
 where key = 'arrived' and type_id is null and exists (select 1 from __S__.harpatka_meeting_types);

do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = '__S__' and p.proname = 'harpatka_me_unregister';
  if d is null then raise exception 'harpatka_me_unregister not found'; end if;
  d := replace(d, E'  if coalesce(a.attended, false) then return ''attended''; end if;\n', '');
  if d like '%return ''attended''%' then raise exception 'attended check still present'; end if;
  execute d;
end $$;
