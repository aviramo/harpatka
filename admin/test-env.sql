-- סביבת בדיקות (24.10.26): סכמה `test` עם העתק של הטבלאות והנתונים. דף admin-test/ עובד רק עליה.
-- הרצה חוזרת = איפוס: מוחק את הסכמה ובונה אותה מחדש מהנתונים האמיתיים (לא נוגע ב-public).
drop schema if exists test cascade;
create schema test;
create table test.harpatka_promoters (like public.harpatka_promoters including all);
create table test.harpatka_participants (like public.harpatka_participants including all);
create table test.harpatka_meetings (like public.harpatka_meetings including all);
create table test.harpatka_attendance (like public.harpatka_attendance including all);
create table test.harpatka_notes (like public.harpatka_notes including all);
create table test.harpatka_promoter_payments (like public.harpatka_promoter_payments including all);
create table test.harpatka_payments (like public.harpatka_payments including all);
create table test.harpatka_members (like public.harpatka_members including all);
create table test.harpatka_posts (like public.harpatka_posts including all);
alter table test.harpatka_members add constraint harpatka_members_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES test.harpatka_participants(id) ON DELETE SET NULL;
alter table test.harpatka_attendance add constraint harpatka_attendance_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES test.harpatka_participants(id) ON DELETE CASCADE;
alter table test.harpatka_attendance add constraint harpatka_attendance_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES test.harpatka_meetings(id) ON DELETE CASCADE;
alter table test.harpatka_notes add constraint harpatka_notes_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES test.harpatka_participants(id) ON DELETE CASCADE;
alter table test.harpatka_participants add constraint harpatka_participants_promoter_id_fkey FOREIGN KEY (promoter_id) REFERENCES test.harpatka_promoters(id) ON DELETE SET NULL;
alter table test.harpatka_attendance add constraint harpatka_attendance_promoter_id_fkey FOREIGN KEY (promoter_id) REFERENCES test.harpatka_promoters(id) ON DELETE SET NULL;
alter table test.harpatka_promoter_payments add constraint harpatka_promoter_payments_promoter_id_fkey FOREIGN KEY (promoter_id) REFERENCES test.harpatka_promoters(id) ON DELETE CASCADE;
alter table test.harpatka_payments add constraint harpatka_payments_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES test.harpatka_participants(id) ON DELETE CASCADE;
alter table test.harpatka_payments add constraint harpatka_payments_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES test.harpatka_meetings(id) ON DELETE SET NULL;
alter table test.harpatka_payments add constraint harpatka_payments_promoter_id_fkey FOREIGN KEY (promoter_id) REFERENCES test.harpatka_promoters(id) ON DELETE SET NULL;
alter table test.harpatka_posts add constraint harpatka_posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES test.harpatka_posts(id) ON DELETE CASCADE;
alter table test.harpatka_posts add constraint harpatka_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES test.harpatka_members(user_id) ON DELETE RESTRICT;
insert into test.harpatka_promoters ("id", "name", "rate_type", "rate", "created_at") select "id", "name", "rate_type", "rate", "created_at" from public.harpatka_promoters;
insert into test.harpatka_participants ("id", "phone", "phone_norm", "source", "age", "age_set_at", "note", "created_at", "gender", "promoter_id", "first_name", "last_name", "active") select "id", "phone", "phone_norm", "source", "age", "age_set_at", "note", "created_at", "gender", "promoter_id", "first_name", "last_name", "active" from public.harpatka_participants;
insert into test.harpatka_meetings ("id", "meeting_date", "meeting_time", "created_at") select "id", "meeting_date", "meeting_time", "created_at" from public.harpatka_meetings;
insert into test.harpatka_attendance ("participant_id", "meeting_id", "paid", "created_at", "pay_requested_at", "exempt", "attended", "attended_at", "paid_amount", "promoter_id", "commission", "paid_at", "pay_method", "pay_method_note", "details_sent_at", "will_pay", "maybe") select "participant_id", "meeting_id", "paid", "created_at", "pay_requested_at", "exempt", "attended", "attended_at", "paid_amount", "promoter_id", "commission", "paid_at", "pay_method", "pay_method_note", "details_sent_at", "will_pay", "maybe" from public.harpatka_attendance;
insert into test.harpatka_notes ("id", "participant_id", "body", "author_email", "author_name", "created_at", "image", "system", "event_type", "meeting_id", "old_status", "new_status", "amount", "source", "method") select "id", "participant_id", "body", "author_email", "author_name", "created_at", "image", "system", "event_type", "meeting_id", "old_status", "new_status", "amount", "source", "method" from public.harpatka_notes;
insert into test.harpatka_promoter_payments ("id", "promoter_id", "amount", "paid_at", "note", "created_at") select "id", "promoter_id", "amount", "paid_at", "note", "created_at" from public.harpatka_promoter_payments;
insert into test.harpatka_payments ("id", "participant_id", "meeting_id", "kind", "amount", "promoter_id", "commission", "author_name", "created_at", "from_credit", "method", "method_note") select "id", "participant_id", "meeting_id", "kind", "amount", "promoter_id", "commission", "author_name", "created_at", "from_credit", "method", "method_note" from public.harpatka_payments;
insert into test.harpatka_members ("user_id", "email", "google_name", "phone_norm", "participant_id", "status", "created_at") select "user_id", "email", "google_name", "phone_norm", "participant_id", "status", "created_at" from public.harpatka_members;
insert into test.harpatka_posts ("id", "parent_id", "root_id", "user_id", "body", "created_at", "deleted_at", "approved_at", "share_phone", "edited_at", "pending_body", "hidden_at", "show_name", "author_first") select "id", "parent_id", "root_id", "user_id", "body", "created_at", "deleted_at", "approved_at", "share_phone", "edited_at", "pending_body", "hidden_at", "show_name", "author_first" from public.harpatka_posts;
grant usage on schema test to anon, authenticated, service_role;
alter table test.harpatka_promoters enable row level security;
create policy "harpatka admin all" on test.harpatka_promoters for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_participants enable row level security;
create policy "harpatka admin all" on test.harpatka_participants for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_meetings enable row level security;
create policy "harpatka admin all" on test.harpatka_meetings for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_attendance enable row level security;
create policy "harpatka admin all" on test.harpatka_attendance for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_notes enable row level security;
create policy "harpatka admin all" on test.harpatka_notes for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_promoter_payments enable row level security;
create policy "harpatka admin all" on test.harpatka_promoter_payments for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_payments enable row level security;
create policy "harpatka admin all" on test.harpatka_payments for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_members enable row level security;
create policy "harpatka admin all" on test.harpatka_members for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
alter table test.harpatka_posts enable row level security;
create policy "harpatka admin all" on test.harpatka_posts for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin());
create policy "harpatka public read meetings" on test.harpatka_meetings for select to anon, authenticated using (true);
grant all on all tables in schema test to authenticated, service_role;
grant select on test.harpatka_meetings to anon;
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
    if os <> ns then
      perform test.harpatka_sys_note(new.participant_id, 'סטטוס למפגש ' || test.harpatka_meeting_short(new.meeting_id) || ': ' || ns
        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end
        || case when ns = 'שילם' and new.pay_method is not null then ' ב' || test.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end || ' (היה: ' || os || ')',
        'status_changed', new.meeting_id, test.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe), test.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe), case when ns = 'שילם' then new.paid_amount end, null, case when ns = 'שילם' then new.pay_method end);
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
CREATE OR REPLACE FUNCTION test.harpatka_meeting_label(p_mid uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'test'
AS $function$
  select 'יום ' || (array['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת'])[extract(dow from m.meeting_date)::int + 1] || ' '
    || ltrim(to_char(m.meeting_date, 'DD'), '0') || '.' || ltrim(to_char(m.meeting_date, 'MM'), '0') || ' · ' || to_char(m.meeting_time, 'HH24:MI')
  from test.harpatka_meetings m where m.id = p_mid;
$function$
;
CREATE OR REPLACE FUNCTION test.harpatka_meeting_short(p_mid uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'test'
AS $function$
  select ltrim(to_char(m.meeting_date, 'DD'), '0') || '.' || ltrim(to_char(m.meeting_date, 'MM'), '0') from test.harpatka_meetings m where m.id = p_mid;
$function$
;
CREATE OR REPLACE FUNCTION test.harpatka_method_label(p_method text, p_note text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_method when 'paybox' then 'פייבוקס' when 'bit' then 'ביט' when 'cash' then 'מזומן' when 'bank' then 'בנק'
    when 'other' then 'אחר' || coalesce(': ' || nullif(btrim(p_note), ''), '') else coalesce(p_method, '') end;
$function$
;
CREATE OR REPLACE FUNCTION test.harpatka_part_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'test'
AS $function$
begin
  if current_setting('harpatka.skip_note', true) = '1' then return new; end if;
  if tg_op = 'INSERT' then
    perform test.harpatka_sys_note(new.id, 'נרשם/ה ' || case new.source when 'site-ad' then 'דרך האתר (ממומן)' when 'site' then 'דרך האתר' else '(נוסף/ה ידנית)' end, 'registered', null, null, null, null, coalesce(nullif(new.source, ''), 'manual'));
  elsif tg_op = 'UPDATE' and new.active is distinct from old.active then
    perform test.harpatka_sys_note(new.id, case when new.active then 'חזר/ה להיות פעיל/ה' else 'הוסר/ה (לא פעיל/ה)' end, case when new.active then 'reactivated' else 'deactivated' end);
  end if;
  return new;
exception when others then return new;
end $function$
;
CREATE OR REPLACE FUNCTION test.harpatka_participants_phone_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.phone_norm := public.harpatka_normalize_phone(new.phone);
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION test.harpatka_pay_code(p_paid boolean, p_exempt boolean, p_req timestamp with time zone, p_will boolean, p_maybe boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when coalesce(p_exempt, false) then 'exempt' when coalesce(p_paid, false) then 'paid' when coalesce(p_will, false) then 'willpay' when coalesce(p_maybe, false) then 'maybe' when p_req is not null then 'requested' else 'unpaid' end;
$function$
;
CREATE OR REPLACE FUNCTION test.harpatka_pay_status(p_paid boolean, p_exempt boolean, p_req timestamp with time zone, p_will boolean, p_maybe boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when coalesce(p_exempt, false) then 'חינם' when coalesce(p_paid, false) then 'שילם' when coalesce(p_will, false) then 'ישלם' when coalesce(p_maybe, false) then 'ספונטני' when p_req is not null then 'בטיפול' else 'חדש' end;
$function$
;
CREATE OR REPLACE FUNCTION test.harpatka_sys_note(p_pid uuid, p_body text, p_event text DEFAULT NULL::text, p_meeting uuid DEFAULT NULL::uuid, p_old text DEFAULT NULL::text, p_new text DEFAULT NULL::text, p_amount numeric DEFAULT NULL::numeric, p_source text DEFAULT NULL::text, p_method text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'test'
AS $function$
declare actor text := coalesce(nullif(auth.jwt() -> 'user_metadata' ->> 'full_name', ''), auth.jwt() ->> 'email');
begin
  -- כותב ההערה הוא מי שביצע את השינוי (מנהל); בהרשמה מהאתר, בלי מנהל: "מערכת". הטקסט בלי "בוצע על ידי".
  insert into test.harpatka_notes (participant_id, body, author_email, author_name, system, event_type, meeting_id, old_status, new_status, amount, source, method)
  values (p_pid, p_body, coalesce(auth.jwt() ->> 'email', 'system'), coalesce(actor, 'מערכת'), true, p_event, p_meeting, p_old, p_new, p_amount, p_source, p_method);
exception when others then null;
end $function$
;
grant execute on all functions in schema test to authenticated, anon, service_role;
CREATE TRIGGER harpatka_att_notes AFTER INSERT OR DELETE OR UPDATE OF paid, exempt, pay_requested_at, will_pay, maybe, attended, details_sent_at ON test.harpatka_attendance FOR EACH ROW EXECUTE FUNCTION test.harpatka_att_notes();
CREATE TRIGGER harpatka_part_notes AFTER INSERT OR UPDATE OF active ON test.harpatka_participants FOR EACH ROW EXECUTE FUNCTION test.harpatka_part_notes();
CREATE TRIGGER harpatka_participants_phone BEFORE INSERT OR UPDATE OF phone ON test.harpatka_participants FOR EACH ROW EXECUTE FUNCTION test.harpatka_participants_phone_trg();
alter role authenticator set pgrst.db_schemas = 'public, storage, graphql_public, test';
alter publication supabase_realtime add table test.harpatka_participants;
alter publication supabase_realtime add table test.harpatka_meetings;
alter publication supabase_realtime add table test.harpatka_attendance;
alter publication supabase_realtime add table test.harpatka_notes;
alter publication supabase_realtime add table test.harpatka_promoters;
alter publication supabase_realtime add table test.harpatka_promoter_payments;
alter publication supabase_realtime add table test.harpatka_payments;
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
