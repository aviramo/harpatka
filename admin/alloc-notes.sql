-- הערות מערכת על תשלומים (28.10.26): קבלת תשלום (הפקדה או תשלום ישיר), החזר כסף, והקצאות למפגש (kind = 'payment' עם מפגש):
-- הקצאה חדשה, שינוי סכום הקצאה והסרת הקצאה. הפקדה שנוצרה ממחיקת הקצאה (reason alloc_removed) לא מקבלת הערת קבלה. אידמפוטנטי. להריץ על public ועל test (החלפת __S__ בשם הסכמה):
--   sed 's/__S__/public/g' admin/alloc-notes.sql | supabase db query --linked   (וגם עם test)
create or replace function __S__.harpatka_pay_notes()
returns trigger language plpgsql security definer set search_path = __S__ as $$
declare r __S__.harpatka_payments; src text; lbl text;
begin
  r := case when tg_op = 'DELETE' then old else new end;
  if r.kind = 'deposit' then
    if tg_op = 'INSERT' and coalesce(r.reason, '') not like 'alloc_removed%' then
      perform __S__.harpatka_sys_note(r.participant_id, 'התקבל תשלום ₪' || trim(to_char(r.amount, 'FM999990.##')) || coalesce(' ב' || __S__.harpatka_method_label(r.method, r.method_note), ''), 'payment_received', null, null, null, r.amount, null);
    end if;
    return null;
  end if;
  if r.kind = 'refund' then
    if tg_op = 'INSERT' then
      perform __S__.harpatka_sys_note(r.participant_id, 'הוחזרו ₪' || trim(to_char(r.amount, 'FM999990.##')) || ' למשתתף' || case when r.meeting_id is not null then ' (למפגש ' || __S__.harpatka_meeting_short(r.meeting_id) || ')' else '' end || coalesce(' ב' || __S__.harpatka_method_label(r.method, r.method_note), ''), 'refund', r.meeting_id, null, null, r.amount, null);
    end if;
    return null;
  end if;
  if r.kind <> 'payment' or r.meeting_id is null then return null; end if;
  src := case when coalesce(r.from_credit, false) then 'מהיתרה' else coalesce('ב' || __S__.harpatka_method_label(r.method, r.method_note), 'ישירות') end;
  lbl := __S__.harpatka_meeting_short(r.meeting_id);
  if tg_op = 'INSERT' then
    if not coalesce(r.from_credit, false) then perform __S__.harpatka_sys_note(r.participant_id, 'התקבל תשלום ₪' || trim(to_char(r.amount, 'FM999990.##')) || coalesce(' ב' || __S__.harpatka_method_label(r.method, r.method_note), ''), 'payment_received', null, null, null, r.amount, null); end if;
    perform __S__.harpatka_sys_note(r.participant_id, 'הוקצו ₪' || trim(to_char(r.amount, 'FM999990.##')) || ' למפגש ' || lbl || ' (' || src || ')', 'alloc_added', r.meeting_id, null, null, r.amount, null);
  elsif tg_op = 'UPDATE' then
    if new.amount is distinct from old.amount then
      perform __S__.harpatka_sys_note(r.participant_id, 'הקצאה למפגש ' || lbl || ' (' || src || ') שונתה מ-₪' || trim(to_char(old.amount, 'FM999990.##')) || ' ל-₪' || trim(to_char(new.amount, 'FM999990.##')), 'alloc_changed', r.meeting_id, null, null, new.amount, null);
    end if;
  elsif tg_op = 'DELETE' then
    perform __S__.harpatka_sys_note(r.participant_id, 'הוסרה הקצאה של ₪' || trim(to_char(r.amount, 'FM999990.##')) || ' למפגש ' || lbl || ' (' || src || ')', 'alloc_removed', r.meeting_id, null, null, r.amount, null);
  end if;
  return null;
exception when others then return null;
end $$;
drop trigger if exists harpatka_pay_notes on __S__.harpatka_payments;
create trigger harpatka_pay_notes after insert or update or delete on __S__.harpatka_payments for each row execute function __S__.harpatka_pay_notes();
