-- מייל אישור תשלום בסגירת תשלום (2.11.26). הסגירה עצמה נעשית בדף הניהול (מחיקת pay_due_amount); הפונקציה הזו רק שולחת את המייל "התשלום התקבל".
-- נשלח רק אם המשתתף באמת שילם: נטו ההקצאות למפגש גדול מאפס, המפגש לא חינם ולא נשארה שארית. פעם אחת לכל מפגש (pay_mail_sent_at).
-- מחזיר: sent, no_email (אין חשבון מחובר), unpaid, skip, already, past (המפגש כבר עבר: הנוסח אומר "המקום שלך שמור" ו"איך מגיעים").
-- אידמפוטנטי. להריץ אחרי payment-mail.sql. להחליף __S__ ב-test או ב-public ו-__ADM__ בפונקציית בדיקת המנהל (test: harpatka_is_admin_site, public: harpatka_is_admin):
--   sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin_site/g' admin/pay-close-mail.sql | supabase db query --linked
--   sed 's/__S__/public/g; s/__ADM__/harpatka_is_admin/g' admin/pay-close-mail.sql | supabase db query --linked
create or replace function __S__.harpatka_close_payment_mail(p_pid uuid, p_mid uuid)
returns text language plpgsql security definer set search_path = __S__, public as $f$
declare a __S__.harpatka_attendance; mt __S__.harpatka_meetings; net numeric;
begin
  if not __S__.__ADM__() then raise exception 'forbidden'; end if;
  select * into a from __S__.harpatka_attendance where participant_id = p_pid and meeting_id = p_mid;
  if not found or coalesce(a.no_pay, false) or coalesce(a.pay_due_amount, 0) > 0 then return 'skip'; end if;
  select coalesce(sum(case when kind = 'payment' then amount when kind = 'credit' or (kind = 'refund' and not coalesce(from_credit, false)) then -amount else 0 end), 0) into net
    from __S__.harpatka_payments where participant_id = p_pid and meeting_id = p_mid;
  if net <= 0 then return 'unpaid'; end if;
  if a.pay_mail_sent_at is not null then return 'already'; end if;
  select * into mt from __S__.harpatka_meetings where id = p_mid;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return 'past'; end if;
  if __S__.harpatka_pay_mail(p_pid, p_mid) then
    update __S__.harpatka_attendance set pay_mail_sent_at = now() where participant_id = p_pid and meeting_id = p_mid;
    return 'sent';
  end if;
  return 'no_email';
end $f$;
revoke all on function __S__.harpatka_close_payment_mail(uuid, uuid) from public, anon;
grant execute on function __S__.harpatka_close_payment_mail(uuid, uuid) to authenticated;
