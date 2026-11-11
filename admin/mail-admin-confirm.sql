-- מייל אישור תשלום או "המקום שלך שמור" לא נשלח אוטומטית כשמנהל סוגר תשלום או מסמן "לא לתשלום" (11.11.26).
-- המנהל מקבל בדף הניהול פופאפ ("לשלוח למשתתף מייל?") ורק באישור המייל נשלח, כמו בהודעות וואטסאפ.
-- פעולה של המשתתף עצמו (למשל ניצול קרדיט באזור האישי) ממשיכה לשלוח אוטומטית: הטריגרים מדלגים רק כשהפעולה בוצעה בידי מנהל.
-- harpatka_close_payment_mail(p_pid, p_mid, p_dry): p_dry = true רק בודק ומחזיר ready (אפשר לשלוח) או no_email (למשתתף אין חשבון מחובר);
--   בלי p_dry שולח (תשלום ששולם במלואו: מייל "התשלום התקבל"; מפגש "לא לתשלום": "המקום שלך שמור"). מחזיר: sent, no_email, already, unpaid, skip, past, ready.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public ו-__ADM__ בפונקציית בדיקת המנהל (test: harpatka_is_admin_site, public: harpatka_is_admin):
--   sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin_site/g' admin/mail-admin-confirm.sql | supabase db query --linked
--   sed 's/__S__/public/g; s/__ADM__/harpatka_is_admin/g' admin/mail-admin-confirm.sql | supabase db query --linked
create or replace function __S__.harpatka_pay_mail_fn() returns trigger
language plpgsql security definer set search_path to '__S__', 'public' as $f$
declare a __S__.harpatka_attendance; net numeric;
begin
  if new.kind <> 'payment' or new.meeting_id is null then return null; end if;
  if __S__.__ADM__() then return null; end if;   -- מנהל פועל מדף הניהול: המייל נשלח רק באישור שלו (פופאפ)
  if coalesce(current_setting('harpatka.skip_pay_mail', true), '') = '1' then return null; end if;   -- ניצול קרדיט של המשתתף עצמו שולח בעצמו
  select * into a from __S__.harpatka_attendance where participant_id = new.participant_id and meeting_id = new.meeting_id;
  if not found or coalesce(a.no_pay, false) then return null; end if;
  if coalesce(new.reason, '') like 'partial_due:%' then return null; end if;   -- תשלום חלקי: בלי מייל
  if a.pay_mail_sent_at is not null or coalesce(a.pay_due_amount, 0) > 0 then return null; end if;
  select coalesce(sum(case when kind = 'payment' then amount when kind = 'credit' or (kind = 'refund' and not coalesce(from_credit, false)) then -amount else 0 end), 0) into net
    from __S__.harpatka_payments where participant_id = new.participant_id and meeting_id = new.meeting_id;
  if net <= 0 then return null; end if;
  if __S__.harpatka_pay_mail(new.participant_id, new.meeting_id) then
    update __S__.harpatka_attendance set pay_mail_sent_at = now() where participant_id = new.participant_id and meeting_id = new.meeting_id;
  end if;
  return null;
exception when others then return null;
end $f$;

create or replace function __S__.harpatka_no_pay_mail_fn() returns trigger
language plpgsql security definer set search_path to '__S__', 'public' as $f$
declare mt __S__.harpatka_meetings;
begin
  if not coalesce(new.no_pay, false) or coalesce(old.no_pay, false) then return null; end if;
  if __S__.__ADM__() then return null; end if;   -- מנהל פועל מדף הניהול: המייל נשלח רק באישור שלו (פופאפ)
  select * into mt from __S__.harpatka_meetings where id = new.meeting_id;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return null; end if;   -- מפגש שעבר: בלי מייל
  perform __S__.harpatka_mail_close('place_saved', new.participant_id, new.meeting_id, __S__.harpatka_mail_common(new.participant_id, new.meeting_id)
    || jsonb_build_object('body_block', __S__.harpatka_confirm_text(new.participant_id, new.meeting_id, true)));
  return null;
exception when others then return null;
end $f$;

drop function if exists __S__.harpatka_close_payment_mail(uuid, uuid);
create or replace function __S__.harpatka_close_payment_mail(p_pid uuid, p_mid uuid, p_dry boolean default false) returns text
language plpgsql security definer set search_path to '__S__', 'public' as $f$
declare a __S__.harpatka_attendance; mt __S__.harpatka_meetings; net numeric; em text; nopay boolean;
begin
  if not __S__.__ADM__() then raise exception 'forbidden'; end if;
  select * into a from __S__.harpatka_attendance where participant_id = p_pid and meeting_id = p_mid;
  if not found then return 'skip'; end if;
  select * into mt from __S__.harpatka_meetings where id = p_mid;
  if not found or mt.meeting_date < (now() at time zone 'Asia/Jerusalem')::date then return 'past'; end if;
  if a.pay_mail_sent_at is not null then return 'already'; end if;
  nopay := coalesce(a.no_pay, false);
  if not nopay then
    if coalesce(a.pay_due_amount, 0) > 0 then return 'skip'; end if;
    select coalesce(sum(case when kind = 'payment' then amount when kind = 'credit' or (kind = 'refund' and not coalesce(from_credit, false)) then -amount else 0 end), 0) into net
      from __S__.harpatka_payments where participant_id = p_pid and meeting_id = p_mid;
    if net <= 0 then return 'unpaid'; end if;
  end if;
  select lower(m.email) into em from __S__.harpatka_members m where m.participant_id = p_pid and coalesce(m.email, '') <> '' and m.status <> 'blocked' order by (m.status = 'approved') desc limit 1;
  if p_dry then return case when em is null then 'no_email' else 'ready' end; end if;
  if nopay then
    if __S__.harpatka_mail_close('place_saved', p_pid, p_mid, __S__.harpatka_mail_common(p_pid, p_mid)
        || jsonb_build_object('body_block', __S__.harpatka_confirm_text(p_pid, p_mid, true))) then return 'sent'; end if;
    return 'no_email';
  end if;
  if __S__.harpatka_pay_mail(p_pid, p_mid) then
    update __S__.harpatka_attendance set pay_mail_sent_at = now() where participant_id = p_pid and meeting_id = p_mid;
    return 'sent';
  end if;
  return 'no_email';
end $f$;
revoke all on function __S__.harpatka_close_payment_mail(uuid, uuid, boolean) from public, anon;
grant execute on function __S__.harpatka_close_payment_mail(uuid, uuid, boolean) to authenticated;
