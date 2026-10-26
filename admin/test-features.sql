-- פיצ'רים חדשים בסביבת הבדיקות בלבד (סכמה test; לא נוגע ב-public). להריץ שוב אחרי כל איפוס של test-env.sql.
-- 1. הפקדות: תשלום שהתקבל בלי קשר למפגש (kind = deposit) נכנס ליתרה של המשתתף
alter table test.harpatka_payments drop constraint if exists harpatka_payments_kind_check;
alter table test.harpatka_payments add constraint harpatka_payments_kind_check check (kind in ('payment', 'refund', 'credit', 'deposit'));

-- 2. ניהול סטטוסים: שם, צבע (מפתח בפלטה) וסדר לכל סטטוס (המפתחות והתנהגות הסינון קבועים)
create table if not exists test.harpatka_statuses (
  key text primary key,
  label text not null,
  color text not null,
  sort int not null
);
insert into test.harpatka_statuses (key, label, color, sort) values
  ('paid', 'שילם', 'green', 1),
  ('willpay', 'ישלם', 'red', 2),
  ('exempt', 'חינם', 'sky', 3),
  ('maybe', 'ספונטני', 'sky', 4),
  ('requested', 'בטיפול', 'amber', 5),
  ('unpaid', 'חדש', 'red', 6)
on conflict (key) do nothing;
alter table test.harpatka_statuses enable row level security;
drop policy if exists "harpatka admin all" on test.harpatka_statuses;
create policy "harpatka admin all" on test.harpatka_statuses for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on test.harpatka_statuses to authenticated, service_role;
do $$ begin
  alter publication supabase_realtime add table test.harpatka_statuses;
exception when duplicate_object then null; end $$;
notify pgrst, 'reload schema';

-- 3. הערת מערכת על הפקדה (תשלום שהתקבל בלי קשר למפגש)
create or replace function test.harpatka_pay_notes()
returns trigger language plpgsql security definer set search_path to 'test' as $$
begin
  if new.kind = 'deposit' then
    perform test.harpatka_sys_note(new.participant_id,
      'התקבל תשלום ₪' || trim(to_char(new.amount, 'FM999990.##')) || coalesce(' ב' || test.harpatka_method_label(new.method, new.method_note), ''),
      'deposit', null, null, null, new.amount, null);
  end if;
  return null;
exception when others then return null;
end $$;
drop trigger if exists harpatka_pay_notes on test.harpatka_payments;
create trigger harpatka_pay_notes after insert on test.harpatka_payments for each row execute function test.harpatka_pay_notes();
