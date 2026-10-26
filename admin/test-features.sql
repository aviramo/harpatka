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
  ('willpay', 'ישלם', 'neutral', 2),
  ('exempt', 'חינם', 'sky', 3),
  ('maybe', 'ספונטני', 'sky', 4),
  ('requested', 'בטיפול', 'amber', 5),
  ('unpaid', 'חדש', 'red', 99)
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

-- 4. העדפות מנהל: שם השולח בהודעות (לכל מנהל לפי אימייל)
create table if not exists test.harpatka_admin_prefs (
  email text primary key,
  sender_name text
);
alter table test.harpatka_admin_prefs enable row level security;
drop policy if exists "harpatka admin all" on test.harpatka_admin_prefs;
create policy "harpatka admin all" on test.harpatka_admin_prefs for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant all on test.harpatka_admin_prefs to authenticated, service_role;
notify pgrst, 'reload schema';

-- 5. ישלם בצבע ניטרלי (במקום אדום, כדי שלא יהיו שני אדומים)
update test.harpatka_statuses set color = 'neutral' where key = 'willpay' and color = 'red';

-- 6. "חדש" הוא סטטוס מערכת: תמיד אחרון (ונעול בממשק)
update test.harpatka_statuses set sort = 99, label = 'חדש', color = 'red' where key = 'unpaid';

-- 7. הפרדה: סטטוסי מפגש (לכל שיוך) וסטטוסי משתתף (כללי). scope = meeting | participant
alter table test.harpatka_statuses add column if not exists scope text not null default 'meeting';
alter table test.harpatka_participants add column if not exists status_key text;
insert into test.harpatka_statuses (key, label, color, sort, scope) values
  ('p_active', 'פעיל', 'green', 1, 'participant'),
  ('p_inactive', 'לא פעיל', 'neutral', 2, 'participant'),
  ('p_new', 'חדש', 'red', 99, 'participant')
on conflict (key) do nothing;
notify pgrst, 'reload schema';
