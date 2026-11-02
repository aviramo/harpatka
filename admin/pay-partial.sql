-- תשלום חלקי שמנהל רושם (לא הנחה): "נשאר לשלם". מריצים פעם ב-test ופעם ב-public (להחליף __S__ בשם הסכמה). אידמפוטנטי.
-- ההקצאה נרשמת עם reason = 'partial_due:<סכום>', ובאותה טרנזקציה:
-- * הסכום נשמר ב-harpatka_attendance.pay_due_amount (כמו שארית אחרי ניצול קרדיט), והמשתתף רואה כפתור תשלום על השארית.
-- * במקום מייל "התשלום התקבל" נשלח מייל "התקבל תשלום, נשאר להשלים".
-- תשלום רגיל שנרשם אחר כך מנקה את השארית ושולח "התשלום התקבל", כמו קודם.

create or replace function __S__.harpatka_clear_pay_reported() returns trigger
language plpgsql security definer set search_path = __S__, public as $function$
declare rem numeric;
begin
  if new.meeting_id is not null and new.kind = 'payment' then
    rem := nullif(substring(coalesce(new.reason, '') from '^partial_due:([0-9.]+)$'), '')::numeric;
    update __S__.harpatka_attendance set pay_reported_at = null, pay_rejected_at = null, pay_due_amount = rem
      where participant_id = new.participant_id and meeting_id = new.meeting_id and (rem is not null or pay_reported_at is not null or pay_rejected_at is not null or pay_due_amount is not null);
    if rem is not null then
      begin
        perform __S__.harpatka_sys_note(new.participant_id, 'נשאר לשלם ₪' || trim_scale(rem)::text || ' למפגש ' || __S__.harpatka_meeting_short(new.meeting_id), 'payment_due', new.meeting_id);
      exception when others then null;
      end;
    end if;
  end if;
  return new;
end $function$;

create or replace function __S__.harpatka_pay_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare a __S__.harpatka_attendance; net numeric;
begin
  if new.kind <> 'payment' or new.meeting_id is null then return null; end if;
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
