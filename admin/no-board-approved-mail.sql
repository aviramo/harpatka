-- לוח השיתופים הוסר מהאתר, ולכן משתתף לא מקבל יותר את המייל "החיבור שלך ללוח השיתופים אושר" (2.11.26).
-- אישור חיבור ממשיך לפרסם פוסטים שהמתינו, בלי מייל. התבנית member_approved נשארה בטבלה בלי שימוש. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/no-board-approved-mail.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/no-board-approved-mail.sql | supabase db query --linked
create or replace function __S__.harpatka_members_publish_pending() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    update __S__.harpatka_posts set approved_at = now() where user_id = new.user_id and approved_at is null and deleted_at is null;
  end if;
  return null;
end $f$;
