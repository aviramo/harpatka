-- ==========================================================================
-- סביבת בדיקות לאתר כולו (test.harpatka.co.il): משלים בסכמת test את מה שהאתר הציבורי צריך:
-- טבלאות הלוח (לבבות, לבבות אנונימיים) והגדרות ריקות, כל הפונקציות harpatka_* של public (הרשמה, לוח, אזור אישי, ...)
-- בעותק שעובד על טבלאות test, הרשאות זהות, וטריגר פרסום פוסטים ממתינים.
-- מיילים בבדיקות כבויים: harpatka_send_mail בסכמת test היא פונקציה ריקה (לא שולחת כלום).
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

-- מיילים: פונקציה ריקה (אותה חתימה כמו של public)
create or replace function test.harpatka_send_mail(p_key text, p_vars jsonb, p_to text default null, p_extra jsonb default null)
returns void language sql as $$ select $$;

do $copy$
declare
  r record; def text; args text; role_name text;
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) ia
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'harpatka\_%'
      and p.proname not in ('harpatka_is_admin', 'harpatka_send_mail', 'harpatka_render', 'harpatka_html_esc', 'harpatka_board_signal', 'harpatka_posts_notify_comment')
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'public.harpatka_', 'test.harpatka_');
    def := replace(def, 'test.harpatka_is_admin', 'public.harpatka_is_admin');
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
