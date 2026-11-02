-- ==========================================================================
-- סביבת בדיקות לאתר כולו (test.harpatka.co.il): משלים בסכמת test את מה שהאתר הציבורי צריך:
-- טבלאות הלוח (לבבות, לבבות אנונימיים) והגדרות ריקות, כל הפונקציות harpatka_* של public (הרשמה, לוח, אזור אישי, ...)
-- בעותק שעובד על טבלאות test, הרשאות זהות, וטריגר פרסום פוסטים ממתינים.
-- מיילים בבדיקות יוצאים רק לאופיר: harpatka_send_mail בסכמת test מוגדרת ב-admin/mail-log.sql.
-- הכתובת האמיתית של חיבור המנהלים נשארת public.harpatka_is_admin / public.harpatka_admins (אותם מנהלים).
-- אידמפוטנטי; להריץ שוב אחרי כל שינוי בפונקציות של public ואחרי איפוס הסכמה (test-env.sql).
-- ==========================================================================
set check_function_bodies = off;

create table if not exists test.harpatka_likes (like public.harpatka_likes including all);
create table if not exists test.harpatka_anon_likes (like public.harpatka_anon_likes including all);
create table if not exists test.harpatka_settings (like public.harpatka_settings including all);
alter table test.harpatka_likes enable row level security;
alter table test.harpatka_anon_likes enable row level security;
alter table test.harpatka_settings enable row level security;

-- מיילים בבדיקות (30.10.26): נשלחים דרך Resend רק לאופיר (ofir.aviram@gmail.com), לעולם לא להדר ולא למשתתפים (הנמען שהתבקש נדרס),
-- עם "[בדיקות]" בנושא, וכל קישור ל-harpatka.co.il מוחלף ב-test.harpatka.co.il. הטמפלטים מ-test.harpatka_mail_templates (עותק של public, וטמפלטים חדשים שנבדקים קודם כאן), ואחרת מ-public.
create table if not exists test.harpatka_mail_templates (like public.harpatka_mail_templates including all);
insert into test.harpatka_mail_templates select * from public.harpatka_mail_templates on conflict do nothing;
-- test.harpatka_send_mail מוגדרת ב-admin/mail-log.sql (שולח אחד לשתי הסביבות): להריץ אותו אחרי הקובץ הזה
grant execute on function test.harpatka_is_admin_site() to anon, authenticated;

do $copy$
declare
  r record; def text; args text; role_name text;
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) ia
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'harpatka\_%'
      and p.proname not in ('harpatka_is_admin', 'harpatka_send_mail', 'harpatka_mail_build', 'harpatka_mail_record', 'harpatka_mail_sync', 'harpatka_render', 'harpatka_html_esc', 'harpatka_board_signal', 'harpatka_me_signal', 'harpatka_meetings_signal', 'harpatka_posts_notify_comment')
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'public.harpatka_', 'test.harpatka_');
    def := replace(def, 'test.harpatka_is_admin', 'test.harpatka_is_admin_site');
    def := replace(def, 'test.harpatka_admins', 'public.harpatka_admins');
    def := replace(def, $$search_path TO 'public'$$, $$search_path TO 'test', 'public'$$);
    def := replace(def, 'FUNCTION public.' || r.proname, 'FUNCTION test.' || r.proname);
    -- מסירים קריאות לאותות realtime של הלוח האמיתי
    def := replace(def, 'perform public.harpatka_board_signal();', '');
    execute def;
    execute format('revoke all on function test.%I(%s) from public', r.proname, r.ia);
    foreach role_name in array array['anon', 'authenticated'] loop
      if has_function_privilege(role_name, r.oid, 'execute') then
        execute format('grant execute on function test.%I(%s) to %I', r.proname, r.ia, role_name);
      end if;
    end loop;
  end loop;
end $copy$;

grant select, insert, update, delete on test.harpatka_likes, test.harpatka_anon_likes to postgres;
drop trigger if exists harpatka_members_publish_pending on test.harpatka_members;
create trigger harpatka_members_publish_pending after update of status on test.harpatka_members
  for each row execute function test.harpatka_members_publish_pending();

-- קשרים בין טבלאות הלוח בסכמת test (בלעדיהם הטבלאות מועתקות בלי מפתחות זרים, ודף הניהול לא מצליח לטעון את "התחברויות ללוח")
do $fk$
begin
  if not exists (select 1 from pg_constraint where conname = 'harpatka_members_participant_id_fkey' and connamespace = 'test'::regnamespace) then
    alter table test.harpatka_members add constraint harpatka_members_participant_id_fkey foreign key (participant_id) references test.harpatka_participants(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'harpatka_posts_user_id_fkey' and connamespace = 'test'::regnamespace) then
    alter table test.harpatka_posts add constraint harpatka_posts_user_id_fkey foreign key (user_id) references test.harpatka_members(user_id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'harpatka_posts_parent_id_fkey' and connamespace = 'test'::regnamespace) then
    alter table test.harpatka_posts add constraint harpatka_posts_parent_id_fkey foreign key (parent_id) references test.harpatka_posts(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'harpatka_likes_post_id_fkey' and connamespace = 'test'::regnamespace) then
    alter table test.harpatka_likes add constraint harpatka_likes_post_id_fkey foreign key (post_id) references test.harpatka_posts(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'harpatka_likes_user_id_fkey' and connamespace = 'test'::regnamespace) then
    alter table test.harpatka_likes add constraint harpatka_likes_user_id_fkey foreign key (user_id) references test.harpatka_members(user_id) on delete cascade;
  end if;
end $fk$;
notify pgrst, 'reload schema';

-- "דווח" על תשלום: תשלום שנרשם למפגש מנקה את הדיווח (הפונקציה הועתקה למעלה)
drop trigger if exists harpatka_clear_pay_reported on test.harpatka_payments;
create trigger harpatka_clear_pay_reported after insert on test.harpatka_payments for each row execute function test.harpatka_clear_pay_reported();
drop trigger if exists harpatka_member_linked_note on test.harpatka_members;
create trigger harpatka_member_linked_note after insert or update of participant_id on test.harpatka_members for each row execute function test.harpatka_member_linked_note();   -- הערת מערכת: חובר חשבון גוגל
drop trigger if exists harpatka_participant_changes on test.harpatka_participants;
create trigger harpatka_participant_changes after update of first_name, last_name, phone, phone_norm, age, gender on test.harpatka_participants for each row execute function test.harpatka_participant_changes();   -- יומן שינויי ערכים
drop trigger if exists harpatka_att_reject_notify on test.harpatka_attendance;
create trigger harpatka_att_reject_notify after update of pay_rejected_at on test.harpatka_attendance for each row execute function test.harpatka_att_reject_notify();   -- דחיית דיווח: הערת מערכת (ומייל, כבוי בבדיקות)
