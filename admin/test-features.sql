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
  ('unpaid', 'משויך', 'red', 99)
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
update test.harpatka_statuses set sort = 99 where key = 'unpaid';

-- 7. הפרדה: סטטוסי מפגש (לכל שיוך) וסטטוסי משתתף (כללי). scope = meeting | participant
alter table test.harpatka_statuses add column if not exists scope text not null default 'meeting';
alter table test.harpatka_participants add column if not exists status_key text;
insert into test.harpatka_statuses (key, label, color, sort, scope) values
  ('p_active', 'פעיל', 'green', 1, 'participant'),
  ('p_inactive', 'לא פעיל', 'neutral', 2, 'participant'),
  ('p_new', 'חדש', 'red', 99, 'participant')
on conflict (key) do nothing;
notify pgrst, 'reload schema';

-- 8. סטטוס משתתף: רק פעיל / לא פעיל (בלי סטטוס מערכת "חדש"); ברירת המחדל פעיל
update test.harpatka_participants set status_key = null where status_key is not null and status_key not in ('p_active', 'p_inactive');
delete from test.harpatka_statuses where scope = 'participant' and key not in ('p_active', 'p_inactive');

-- 9. סטטוס מפגש מותאם (נוצר בהגדרות): נשמר ב-attendance.status_key, ומופיע בהערות המערכת בשמו
alter table test.harpatka_attendance add column if not exists status_key text;
CREATE OR REPLACE FUNCTION test.harpatka_att_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'test'
AS $function$
declare os text; ns text;
begin
  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if coalesce(new.attended, false) then
      perform test.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || test.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);
    else
      perform test.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || test.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id);
    end if;
  elsif tg_op = 'UPDATE' then
    os := test.harpatka_pay_status(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe); ns := test.harpatka_pay_status(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe);
    if old.status_key is not null then os := coalesce((select label from test.harpatka_statuses where key = old.status_key), os); end if;
    if new.status_key is not null then ns := coalesce((select label from test.harpatka_statuses where key = new.status_key), ns); end if;
    if os <> ns then
      perform test.harpatka_sys_note(new.participant_id, 'סטטוס למפגש ' || test.harpatka_meeting_short(new.meeting_id) || ': ' || ns
        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end
        || case when ns = 'שילם' and new.pay_method is not null then ' ב' || test.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end || ' (היה: ' || os || ')',
        'status_changed', new.meeting_id, coalesce(old.status_key, test.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe)), coalesce(new.status_key, test.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe)), case when ns = 'שילם' then new.paid_amount end, null, case when ns = 'שילם' then new.pay_method end);
    end if;
    if coalesce(old.attended, false) <> coalesce(new.attended, false) then
      perform test.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || test.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);
    end if;
    if (old.details_sent_at is null) <> (new.details_sent_at is null) then
      perform test.harpatka_sys_note(new.participant_id, case when new.details_sent_at is not null then 'נשלחו פרטי הערב (וואטסאפ) למפגש ' else 'סימון שליחת פרטי הערב בוטל למפגש ' end || test.harpatka_meeting_short(new.meeting_id),
        case when new.details_sent_at is not null then 'details_sent' else 'details_unsent' end, new.meeting_id);
    end if;
  elsif tg_op = 'DELETE' then
    perform test.harpatka_sys_note(old.participant_id, 'הוסר/ה מהמפגש ' || test.harpatka_meeting_short(old.meeting_id), 'meeting_removed', old.meeting_id);
  end if;
  return coalesce(new, old);
exception when others then return coalesce(new, old);
end $function$
;
drop trigger if exists harpatka_att_notes on test.harpatka_attendance;
create trigger harpatka_att_notes after insert or update of paid, exempt, pay_requested_at, will_pay, maybe, status_key, attended, details_sent_at or delete on test.harpatka_attendance
  for each row execute function test.harpatka_att_notes();
notify pgrst, 'reload schema';

-- 10. סטטוס משתתף הוא תווית בלבד: כל המשתתפים מועברים לריק (בלי סטטוס)
update test.harpatka_participants set status_key = null where status_key is not null;

-- 11. תגיות משתתף (בחירה מרובה): מערך מפתחות של סטטוסי scope=participant; status_key הישן עובר לתגית אחת
alter table test.harpatka_participants add column if not exists tags text[] not null default '{}';
update test.harpatka_participants set tags = array[status_key] where status_key is not null and cardinality(tags) = 0;
notify pgrst, 'reload schema';

-- 12. נוסח הודעת ההצגה בוואטסאפ (לכל מנהל): {שם} ו-{שולח} מוחלפים בעת השליחה
alter table test.harpatka_admin_prefs add column if not exists wa_intro text;
notify pgrst, 'reload schema';

-- 13. מתי נפתח סימון ההגעה (לכל מנהל): '15','30','60','120' דקות לפני, 'day' = מתחילת יום המפגש, 'always' = תמיד
alter table test.harpatka_admin_prefs add column if not exists att_lead text;
notify pgrst, 'reload schema';

-- 14. מדרגות מחיר למפגש לפי ימים שנותרו: מחיר ממדרגה אחת ועד המדרגה הבאה. days = מספר ימים מינימלי לפני המפגש (המדרגה עם days=0 היא "עד המפגש").
create table if not exists test.harpatka_price_tiers (
  id uuid primary key default gen_random_uuid(),
  days int not null unique check (days >= 0),
  price int not null check (price >= 0)
);
alter table test.harpatka_price_tiers enable row level security;
drop policy if exists "harpatka admin all" on test.harpatka_price_tiers;
create policy "harpatka admin all" on test.harpatka_price_tiers for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant select, insert, update, delete on test.harpatka_price_tiers to authenticated;
insert into test.harpatka_price_tiers (days, price) values (4, 80), (0, 100) on conflict (days) do nothing;
notify pgrst, 'reload schema';

-- 15. חבילות מפגשים: pkg_n בהפקדה (כמה מפגשים נקנו מראש; מחיר למפגש = הסכום חלקי pkg_n), pkg בהקצאה למפגש (נלקחה מחבילה)
alter table test.harpatka_payments add column if not exists pkg_n int;
alter table test.harpatka_payments add column if not exists pkg boolean not null default false;
notify pgrst, 'reload schema';

-- 16. דרכי הגעה: ערוצי פרסום ממומן דינמיים (קוד משלהם בקישור ?s=<code>, שם וצבע), וצבע ליחצנים
create table if not exists test.harpatka_sources (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9]{1,6}$'),
  name text not null,
  color text not null default 'sky',
  sort int not null default 1
);
alter table test.harpatka_sources enable row level security;
drop policy if exists "harpatka admin all" on test.harpatka_sources;
create policy "harpatka admin all" on test.harpatka_sources for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
grant select, insert, update, delete on test.harpatka_sources to authenticated;
insert into test.harpatka_sources (code, name, color, sort) values ('p', 'פייסבוק', 'sky', 1) on conflict (code) do nothing;
alter table test.harpatka_promoters add column if not exists color text not null default 'red';
alter table test.harpatka_participants add column if not exists source_code text;
update test.harpatka_participants set source_code = 'p' where source = 'site-ad' and source_code is null;
notify pgrst, 'reload schema';

-- 17. משתתף שלא אמור לשלם על מפגשים (מארגן, אורח, פטור): לא נדרש ממנו תשלום ולא נספר בחוב
alter table test.harpatka_participants add column if not exists no_pay boolean not null default false;
notify pgrst, 'reload schema';

-- 18. "לא משלם" לכל מפגש: ברירת המחדל במשתתף (no_pay), ועקיפה לכל שיוך למפגש (null = לפי ברירת המחדל של המשתתף)
alter table test.harpatka_attendance add column if not exists no_pay boolean;
notify pgrst, 'reload schema';

-- 19. איחוד דרכי הגעה: יחצנים וערוצי פרסום הם אותה ישות (harpatka_promoters): שם, צבע, קוד בקישור (?s=), עלות לליד (₪ או %), וסימון אם העלות נגזרת מעצם הליד או מתשלום שנכנס למפגש
alter table test.harpatka_promoters add column if not exists code text;
create unique index if not exists test_promoters_code on test.harpatka_promoters (code) where code is not null;
alter table test.harpatka_promoters add column if not exists cost_on_lead boolean not null default false;
insert into test.harpatka_promoters (name, rate_type, rate, color, code, cost_on_lead)
  select s.name, 'fixed', 0, s.color, s.code, true from test.harpatka_sources s where not exists (select 1 from test.harpatka_promoters p where p.code = s.code);
update test.harpatka_participants p set promoter_id = pr.id from test.harpatka_promoters pr where pr.code = p.source_code and p.promoter_id is null;
notify pgrst, 'reload schema';

-- 20. עלות דרך הגעה: ברירת מחדל עלות לליד (₪ קבוע לכל ליד); תיבת "העלות מהתשלום" (cost_from_payment) = העלות היא סכום התשלום שנכנס, בלי ערכים להגדרה
alter table test.harpatka_promoters add column if not exists cost_from_payment boolean not null default false;
update test.harpatka_promoters set cost_on_lead = true, rate_type = 'fixed' where not cost_from_payment;
notify pgrst, 'reload schema';
