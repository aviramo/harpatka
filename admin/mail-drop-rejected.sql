-- בלי מייל למשתתף על דיווח תשלום שנדחה (2.11.26, לבקשת בעל האתר). מריצים אחרי mail-log.sql ו-mail-meeting-box.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-drop-rejected.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-drop-rejected.sql | supabase db query --linked
-- * הדחייה עצמה לא השתנתה: הדיווח מתבטל, נרשמת הערת מערכת, והמשתתף רואה באזור האישי ובדף הבית שהדיווח לא אושר.
-- * הרצה חוזרת של mail-log.sql או payment-reject.sql מחזירה את השליחה: אחריהן מריצים שוב את הקובץ הזה.
create or replace function __S__.harpatka_att_reject_notify() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
begin
  if new.pay_rejected_at is null or new.pay_rejected_at is not distinct from old.pay_rejected_at then return new; end if;
  begin
    perform __S__.harpatka_sys_note(new.participant_id, 'דיווח התשלום נדחה למפגש ' || __S__.harpatka_meeting_short(new.meeting_id), 'payment_rejected', new.meeting_id, null, null, old.pay_reported_amount);
  exception when others then null;
  end;
  return new;
end $f$;
revoke all on function __S__.harpatka_att_reject_notify() from public, anon, authenticated;
delete from __S__.harpatka_mail_templates where key = 'payment_rejected';
