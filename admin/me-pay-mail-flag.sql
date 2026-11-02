-- harpatka_me מחזירה pay_mail: האם מייל "התשלום התקבל" נשלח למפגש (2.11.26). מריצים אחרי me-area.sql ו-mail-meeting-box.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/me-pay-mail-flag.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/me-pay-mail-flag.sql | supabase db query --linked
-- * פופאפ ההרשמה כותב לפיה שפרטי המפגש והוראות ההגעה נשלחו במייל. מייל ששרת המיילים דחה לא נחשב.
-- * הרצה חוזרת של me-area.sql מוחקת את השדה: אחריה מריצים שוב את הקובץ הזה.
do $do$
declare d text; anchor text := $s$'reported', a.pay_reported_at is not null,$s$;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me';
  if position($s$'pay_mail',$s$ in d) = 0 then
    if position(anchor in d) = 0 then raise exception 'harpatka_me patch did not apply'; end if;
    execute replace(d, anchor, $s$'pay_mail', a.pay_mail_sent_at is not null and not exists (select 1 from __S__.harpatka_mail_log l where l.participant_id = a.participant_id and l.meeting_id = a.meeting_id and l.tpl = 'payment_confirmed' and l.status = 'failed'),
      $s$ || anchor);
  end if;
end $do$;
notify pgrst, 'reload schema';
