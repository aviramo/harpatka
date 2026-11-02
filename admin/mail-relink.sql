-- שיוך מחדש למפגש אחרי הסרה: המשתתף מקבל את מייל ההרשמה (2.11.26). מריצים אחרי mail-registered.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-relink.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-relink.sql | supabase db query --linked
-- * מנהל שמשייך משתתף: עדיין בלי מייל, חוץ ממי שהוסר מאותו מפגש קודם לכן, כי הוא קיבל מייל שהרישום בוטל.
-- * כל שאר התנאים של המייל לא השתנו (harpatka_reg_mail_send): פרטים מלאים, לא מפגש שעבר, לא "לא לתשלום", לא כשכבר שולם, פעם אחת לכל רישום.
create or replace function __S__.harpatka_reg_user_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare pa __S__.harpatka_participants;
begin
  if __S__.harpatka_reg_mail_by_admin(new.participant_id)
     and not exists (select 1 from __S__.harpatka_notes n where n.participant_id = new.participant_id and n.meeting_id = new.meeting_id and n.event_type = 'meeting_removed') then
    return null;
  end if;
  select * into pa from __S__.harpatka_participants where id = new.participant_id;
  if not found or not __S__.harpatka_details_done(pa.first_name, pa.last_name, pa.age, pa.gender) then return null; end if;
  perform __S__.harpatka_reg_mail_send(new.participant_id, new.meeting_id);
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את ההרשמה
end $f$;
revoke all on function __S__.harpatka_reg_user_mail_fn() from public, anon, authenticated;
