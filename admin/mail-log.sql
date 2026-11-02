-- תיעוד המיילים שנשלחים למשתתפים (2.11.26). מריצים אחרי payment-mail.sql ו-payment-reject.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-log.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-log.sql | supabase db query --linked
-- * כל מייל שיש לו נמען מפורש (p_to) נשמר ב-harpatka_mail_log עם ה-HTML המדויק שנשלח, ומחובר להערת המערכת של האירוע שגרם לו (harpatka_notes.mail_id):
--   בכרטיס המשתתף ההערה מסתיימת ב"← מייל", ולחיצה מציגה את המייל. אין שורה נפרדת; רק מייל בלי אירוע (למשל אישור חיבור ללוח) מקבל הערה משלו (mail_sent).
-- * מייל יוצא בכל מקרה, ועל כל מייל שיוצא יש תיעוד: התיעוד בשכבות ולעולם לא עוצר את השליחה. נכשל היומן: נשמר בלי השיוך; נכשלה גם השמירה: נרשמת הערה "נשלח מייל".
-- * מייל שלא נשלח מסומן (status = failed, harpatka_notes.mail_failed) עם הסיבה: אין תבנית, שליחה לא מוגדרת, למשתתף אין אימייל, או ששרת המיילים דחה.
--   התשובה של Resend מגיעה אחרי השליחה, ולכן harpatka_mail_sync בודקת אותה כל דקה (pg_cron). "נשלח" = Resend קיבל; החזרה מאוחרת של מייל (bounce) לא נבדקת.
-- * מיילים למנהלים (בלי p_to) לא נשמרים. מיילים ישנים לא נשמרו ולכן אין להם קישור.
create extension if not exists pg_cron;

create table if not exists __S__.harpatka_mail_log (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid references __S__.harpatka_participants(id) on delete set null,
  meeting_id uuid references __S__.harpatka_meetings(id) on delete set null,
  tpl text not null,
  to_addr text,
  subject text,
  html text,
  status text not null default 'pending',   -- pending, sent, failed
  error text,
  request_id bigint,
  sent_at timestamptz not null default now()
);
alter table __S__.harpatka_mail_log add column if not exists status text not null default 'pending';
alter table __S__.harpatka_mail_log add column if not exists error text;
alter table __S__.harpatka_mail_log add column if not exists request_id bigint;
update __S__.harpatka_mail_log set status = 'sent' where status = 'pending' and request_id is null;   -- שורות מלפני שנוסף המעקב
create index if not exists harpatka_mail_log_participant on __S__.harpatka_mail_log (participant_id);
create index if not exists harpatka_mail_log_pending on __S__.harpatka_mail_log (status) where status = 'pending';
alter table __S__.harpatka_mail_log enable row level security;
drop policy if exists "harpatka admin read" on __S__.harpatka_mail_log;
create policy "harpatka admin read" on __S__.harpatka_mail_log for select to authenticated using (public.harpatka_is_admin());
revoke all on __S__.harpatka_mail_log from public, anon;
grant select on __S__.harpatka_mail_log to authenticated;

alter table __S__.harpatka_notes add column if not exists mail_id uuid references __S__.harpatka_mail_log(id) on delete set null;
alter table __S__.harpatka_notes add column if not exists mail_failed boolean not null default false;
alter table __S__.harpatka_notes add column if not exists mail_noaddr boolean not null default false;   -- לא נשלח כי למשתתף אין חשבון גוגל (מוצג בצהוב; תקלה אמיתית באדום)
update __S__.harpatka_notes n set mail_noaddr = true from __S__.harpatka_mail_log l where n.mail_id = l.id and l.status = 'failed' and l.error like 'אין אימייל%' and not n.mail_noaddr;

-- בונה את המייל מהתבנית: הנושא והתוכן כפי שיישלחו. בבדיקות הקישורים לאתר הבדיקות
create or replace function __S__.harpatka_mail_build(p_key text, p_vars jsonb, out ok boolean, out subj text, out body text, out tpl_to text)
language plpgsql security definer set search_path = __S__, public as $f$
declare t record; v jsonb := coalesce(p_vars, '{}'::jsonb); is_test boolean := '__S__' = 'test';
begin
  ok := false;
  select m.subject, m.html, m.to_addr into t from __S__.harpatka_mail_templates m where m.key = p_key;
  if not found and is_test then select m.subject, m.html, m.to_addr into t from public.harpatka_mail_templates m where m.key = p_key; end if;
  if not found then return; end if;
  if is_test then v := replace(v::text, 'https://harpatka.co.il/', 'https://test.harpatka.co.il/')::jsonb; end if;
  ok := true; tpl_to := t.to_addr;
  subj := public.harpatka_render(t.subject, v, false);
  body := public.harpatka_render(t.html, v, true);
  if is_test then body := replace(body, 'https://harpatka.co.il/', 'https://test.harpatka.co.il/'); end if;
end $f$;
revoke all on function __S__.harpatka_mail_build(text, jsonb) from public, anon, authenticated;

drop function if exists __S__.harpatka_mail_record(text, jsonb, text, text, text);
create or replace function __S__.harpatka_mail_record(p_key text, p_vars jsonb, p_to text, p_subject text, p_html text, p_status text default 'pending', p_error text default null)
returns uuid language plpgsql security definer set search_path = __S__, public as $f$
declare
  pid uuid; mid uuid; lid uuid; nid uuid; evs text[]; subj text := p_subject; body text := p_html; bad boolean := p_status = 'failed'; noaddr boolean := p_status = 'failed' and coalesce(p_error, '') like 'אין אימייל%'; adr text := nullif(trim(coalesce(p_to, '')), '');
  actor text := coalesce(nullif(auth.jwt() -> 'user_metadata' ->> 'full_name', ''), auth.jwt() ->> 'email');
begin
  if adr is null and not (bad and coalesce(p_vars ->> '_pid', '') <> '') then return null; end if;   -- מייל למנהלים
  begin pid := nullif(p_vars ->> '_pid', '')::uuid; mid := nullif(p_vars ->> '_mid', '')::uuid; exception when others then null; end;
  if pid is null and adr is not null then
    begin
      select m.participant_id into pid from __S__.harpatka_members m where lower(m.email) = lower(adr) and m.participant_id is not null order by (m.status = 'approved') desc limit 1;
    exception when others then null;
    end;
  end if;
  if body is null then   -- מייל שלא נשלח לפני שנבנה: שומרים מה היה נשלח
    begin select b.subj, b.body into subj, body from __S__.harpatka_mail_build(p_key, p_vars) b; exception when others then null; end;
  end if;
  -- היומן עם התוכן; אם נכשל, בלי השיוך למשתתף ולמפגש
  begin
    insert into __S__.harpatka_mail_log (participant_id, meeting_id, tpl, to_addr, subject, html, status, error)
      values (pid, mid, p_key, adr, subj, body, p_status, p_error) returning id into lid;
  exception when others then
    begin
      insert into __S__.harpatka_mail_log (tpl, to_addr, subject, html, status, error) values (p_key, adr, subj, body, p_status, p_error) returning id into lid;
    exception when others then lid := null;
    end;
  end;
  if pid is null then return lid; end if;   -- נמען בלי משתתף (חשבון שלא מחובר): נשמר ביומן, ואין כרטיס להערה
  -- ההערה של האירוע שגרם למייל, לפי סדר העדיפות
  if lid is not null then
    evs := case p_key
      when 'payment_confirmed' then array['payment_closed', 'alloc_added', 'alloc_changed', 'payment_received']
      when 'payment_partial' then array['payment_due', 'alloc_added', 'payment_received']
      when 'payment_rejected' then array['payment_rejected']
      when 'payment_refunded' then array['refund']
      when 'meeting_removed' then array['meeting_removed']
      when 'place_saved' then array['free_on']
      when 'meeting_registered' then array['registered', 'reregistered', 'reactivated', 'meeting_linked']
      else array[]::text[] end;
    begin
      select n.id into nid from __S__.harpatka_notes n
        where n.participant_id = pid and n.system and n.mail_id is null and n.event_type = any(evs)
          and (mid is null or n.meeting_id is null or n.meeting_id = mid)
          and n.created_at >= now() - interval '2 minutes'
        order by array_position(evs, n.event_type), n.created_at desc limit 1;
      if nid is not null then update __S__.harpatka_notes set mail_id = lid, mail_failed = bad, mail_noaddr = noaddr where id = nid; return lid; end if;
    exception when others then null;
    end;
  end if;
  -- אין הערת אירוע, או שהתוכן לא נשמר: הערה משלו
  begin
    insert into __S__.harpatka_notes (participant_id, body, author_email, author_name, system, event_type, meeting_id, mail_id, mail_failed, mail_noaddr)
      values (pid, case when lid is null then case when bad then 'מייל לא נשלח: ' else 'נשלח מייל: ' end else '' end || coalesce(subj, 'מייל'), coalesce(auth.jwt() ->> 'email', 'system'), coalesce(actor, 'מערכת'), true, 'mail_sent', mid, lid, bad, noaddr);
  exception when others then null;
  end;
  return lid;
exception when others then return null;   -- התיעוד לעולם לא עוצר את שליחת המייל
end $f$;
revoke all on function __S__.harpatka_mail_record(text, jsonb, text, text, text, text, text) from public, anon, authenticated;

-- שולח המיילים היחיד. בבדיקות: הכול רק לאופיר, עם [בדיקות] בנושא
create or replace function __S__.harpatka_send_mail(p_key text, p_vars jsonb default '{}'::jsonb, p_to text default null, p_extra jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = __S__, public as $f$
declare
  is_test boolean := '__S__' = 'test';
  b record; dflt text; recip text; rk text; fr text; u text; tok text; rid bigint; lid uuid;
  v jsonb := coalesce(p_vars, '{}'::jsonb);
begin
  select * into b from __S__.harpatka_mail_build(p_key, v);
  if not b.ok then perform __S__.harpatka_mail_record(p_key, v, p_to, null, null, 'failed', 'אין תבנית למייל הזה'); return; end if;
  select value into dflt from public.harpatka_settings where key = 'mail_to';
  recip := coalesce(nullif(p_to, ''), nullif(b.tpl_to, ''), nullif(dflt, ''));
  select value into rk from public.harpatka_settings where key = 'resend_key';
  select value into fr from public.harpatka_settings where key = 'mail_from';
  if coalesce(rk, '') <> '' and coalesce(fr, '') <> '' then
    if coalesce(recip, '') = '' then return; end if;
    begin
      lid := __S__.harpatka_mail_record(p_key, v, p_to, b.subj, b.body);
      rid := net.http_post(
        url := 'https://api.resend.com/emails',
        body := jsonb_build_object('from', fr,
                  'to', case when is_test then jsonb_build_array('ofir.aviram@gmail.com') else to_jsonb(string_to_array(replace(recip, ' ', ''), ',')) end,
                  'subject', case when is_test then '[בדיקות] ' else '' end || b.subj, 'html', b.body),
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || rk),
        timeout_milliseconds := 30000);
      if lid is not null then update __S__.harpatka_mail_log set request_id = rid where id = lid; end if;
    exception when others then
      perform __S__.harpatka_mail_record(p_key, v, p_to, b.subj, b.body, 'failed', sqlerrm);
    end;
    return;
  end if;
  select value into u   from public.harpatka_settings where key = 'notify_url';
  select value into tok from public.harpatka_settings where key = 'notify_token';
  if coalesce(u, '') = '' or is_test then perform __S__.harpatka_mail_record(p_key, v, p_to, b.subj, b.body, 'failed', 'שליחת מיילים לא מוגדרת'); return; end if;
  begin
    lid := __S__.harpatka_mail_record(p_key, v, p_to, b.subj, b.body);
    rid := net.http_post(
      url := u,
      body := coalesce(p_extra, '{}'::jsonb) || jsonb_build_object('token', tok, 'to', recip, 'subject', b.subj, 'html', b.body),
      headers := jsonb_build_object('Content-Type', 'application/json'),
      timeout_milliseconds := 30000);
    if lid is not null then update __S__.harpatka_mail_log set request_id = rid where id = lid; end if;
  exception when others then
    perform __S__.harpatka_mail_record(p_key, v, p_to, b.subj, b.body, 'failed', sqlerrm);
  end;
exception when others then
  begin perform __S__.harpatka_mail_record(p_key, v, p_to, null, null, 'failed', sqlerrm); exception when others then null; end;
end $f$;

-- התשובות של שרת המיילים: מעדכן את היומן, ומסמן בהערה מייל שלא נשלח. התשובות נשמרות 6 שעות, ולכן רץ כל דקה
create or replace function __S__.harpatka_mail_sync()
returns integer language plpgsql security definer set search_path = __S__, public as $f$
declare r record; n integer := 0; bad boolean; why text;
begin
  for r in
    select l.id, l.sent_at, x.id as xid, x.status_code, x.timed_out, x.error_msg, left(x.content, 200) as content
      from __S__.harpatka_mail_log l left join net._http_response x on x.id = l.request_id
      where l.status = 'pending'
  loop
    if r.xid is null then
      if r.sent_at >= now() - interval '1 hour' then continue; end if;
      bad := true; why := 'לא התקבלה תשובה משרת המיילים';
    else
      bad := coalesce(r.timed_out, false) or r.error_msg is not null or coalesce(r.status_code, 0) not between 200 and 299;
      why := case when bad then coalesce(nullif(r.error_msg, ''), 'שרת המיילים החזיר ' || coalesce(r.status_code::text, 'תקלה') || coalesce(': ' || r.content, '')) end;
    end if;
    update __S__.harpatka_mail_log set status = case when bad then 'failed' else 'sent' end, error = why where id = r.id;
    if bad then update __S__.harpatka_notes set mail_failed = true where mail_id = r.id; end if;
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke all on function __S__.harpatka_mail_sync() from public, anon, authenticated;
do $do$
begin
  perform cron.schedule('harpatka-mail-sync-__S__', '* * * * *', 'select __S__.harpatka_mail_sync()');
  perform cron.schedule('harpatka-cron-cleanup', '0 3 * * *', $c$delete from cron.job_run_details where end_time < now() - interval '7 days'$c$);
end $do$;

-- דחיית דיווח: מזהה המשתתף והמפגש נשלחים לתיעוד, ומי שאין לו אימייל מסומן
create or replace function __S__.harpatka_att_reject_notify() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare mt __S__.harpatka_meetings; pa __S__.harpatka_participants; em text; vars jsonb;
begin
  if new.pay_rejected_at is null or new.pay_rejected_at is not distinct from old.pay_rejected_at then return new; end if;
  select * into mt from __S__.harpatka_meetings where id = new.meeting_id;
  select * into pa from __S__.harpatka_participants where id = new.participant_id;
  begin
    perform __S__.harpatka_sys_note(new.participant_id, 'דיווח התשלום נדחה למפגש ' || __S__.harpatka_meeting_short(new.meeting_id), 'payment_rejected', new.meeting_id, null, null, old.pay_reported_amount);
  exception when others then null;
  end;
  begin
    select lower(m.email) into em from __S__.harpatka_members m where m.participant_id = new.participant_id and coalesce(m.email, '') <> '' order by (m.status = 'approved') desc limit 1;
    vars := jsonb_build_object('_pid', new.participant_id, '_mid', new.meeting_id, 'first_name', coalesce(nullif(pa.first_name, ''), pa.name, ''),
      'meeting', to_char(mt.meeting_date, 'DD.MM') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || coalesce(' · ' || nullif(mt.city, ''), ''),
      'me_link', 'https://harpatka.co.il/me/?m=' || new.meeting_id);
    if em is not null then
      perform __S__.harpatka_send_mail('payment_rejected', vars, em);
    else
      perform __S__.harpatka_mail_record('payment_rejected', vars, null, null, null, 'failed', 'אין אימייל, המשתתף לא מחובר לחשבון גוגל');
    end if;
  exception when others then null;   -- כשל במייל לא מבטל את הדחייה
  end;
  return new;
end $f$;

do $do$
declare d text;
begin
  -- מיילי התשלום: מזהה המשתתף והמפגש נשלחים לתיעוד, השורה הנפרדת "נשלח מייל" יורדת, ומי שאין לו אימייל מסומן (עם המייל שהיה נשלח)
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_pay_mail';
  if d not like '%''_pid''%' then
    d := replace(d, $r$vars := jsonb_build_object('first_name',$r$, $r$vars := jsonb_build_object('_pid', p_pid, '_mid', p_mid, 'first_name',$r$);
    d := regexp_replace(d, $r$begin\s+perform\s+\S+harpatka_sys_note\(p_pid,[^\n]*'payment_mail', p_mid\);\s+exception when others then null;\s+end;\s*$r$, '');
    if d not like '%''_pid''%' or d like '%''payment_mail''%' then raise exception 'harpatka_pay_mail patch did not apply'; end if;
  end if;
  if d not like '%אין אימייל%' and d not like '%harpatka_mail_close%' then   -- אחרי mail-no-pay.sql הטיפול בחסר אימייל נמצא ב-harpatka_mail_close
    d := replace(d, 'if em is null then return false; end if;', '');
    d := replace(d, $r$perform __S__.harpatka_send_mail(case when p_partial then 'payment_partial' else 'payment_confirmed' end, vars, em);$r$, $r$if em is null then
    perform __S__.harpatka_mail_record(case when p_partial then 'payment_partial' else 'payment_confirmed' end, vars, null, null, null, 'failed', 'אין אימייל, המשתתף לא מחובר לחשבון גוגל');
    return false;
  end if;
  perform __S__.harpatka_send_mail(case when p_partial then 'payment_partial' else 'payment_confirmed' end, vars, em);$r$);
    if d not like '%אין אימייל%' or d like '%if em is null then return false%' then raise exception 'harpatka_pay_mail no-email patch did not apply'; end if;
  end if;
  execute d;
end $do$;
notify pgrst, 'reload schema';
