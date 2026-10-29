-- פיצול הערות ישנות "סטטוס למפגש ...: שילם ₪100 בפייבוקס (היה: ...)" לשתי הערות: שינוי הסטטוס, וקבלת התשלום (28.10.26). אידמפוטנטי (פועל רק על הערות שעוד מכילות ₪).
-- להריץ על public ועל test (החלפת __S__ בשם הסכמה):  sed 's/__S__/public/g' admin/split-status-payment-notes.sql | supabase db query --linked
begin;
create temp table _split on commit drop as
  select id, participant_id, author_email, author_name, created_at, source,
         (regexp_match(body, '₪([0-9.]+)'))[1]::numeric as amt,
         coalesce((regexp_match(body, '₪[0-9.]+( ב[^()]*?) \(היה:'))[1], '') as meth
  from __S__.harpatka_notes where system and event_type = 'status_changed' and body ~ '₪';
insert into __S__.harpatka_notes (participant_id, body, author_email, author_name, created_at, system, event_type, amount, source)
  select participant_id, 'התקבל תשלום ₪' || trim(to_char(amt, 'FM999990.##')) || meth, author_email, author_name, created_at + interval '1 millisecond', true, 'payment_received', amt, source from _split;
update __S__.harpatka_notes n set body = regexp_replace(n.body, ' ₪[0-9.]+( ב[^()]*?)? \(היה:', ' (היה:'), amount = null, method = null
  from _split s where n.id = s.id;
commit;
