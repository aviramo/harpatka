-- מיגרציה לסביבת האמת (public), שלב 2: סכימה, פונקציות, נתוני התחלה ותיקוני נתונים (27.10.26)
-- הכול תוספות ואידמפוטנטי (if not exists / on conflict), בטרנזקציה אחת; הממשק הישן (admin/) ממשיך לעבוד.
-- שלב 1 (טבלת הסטטוסים) ב-admin/migrate-statuses.sql. מקור: admin/test-features.sql במצבו הסופי.
begin;
select set_config('harpatka.skip_note', '1', true);   -- בלי הערות מערכת על תיקוני הנתונים שלהלן

-- 1. תשלומים: הפקדות (kind = deposit), חבילות
alter table public.harpatka_payments drop constraint if exists harpatka_payments_kind_check;
alter table public.harpatka_payments add constraint harpatka_payments_kind_check check (kind in ('payment', 'refund', 'credit', 'deposit'));
alter table public.harpatka_payments add column if not exists pkg_n int;
alter table public.harpatka_payments add column if not exists pkg boolean not null default false;

-- 2. שיוך למפגש: סטטוס מותאם ו"לא משלם" לכל מפגש
alter table public.harpatka_attendance add column if not exists status_key text;
alter table public.harpatka_attendance add column if not exists no_pay boolean;

-- 3. משתתפים: תגיות, קוד דרך הגעה (ועמודות ישנות שהממשק החדש מכיר)
alter table public.harpatka_participants add column if not exists tags text[] not null default '{}';
alter table public.harpatka_participants add column if not exists source_code text;
alter table public.harpatka_participants add column if not exists status_key text;
alter table public.harpatka_participants add column if not exists no_pay boolean not null default false;

-- 4. דרכי הגעה (harpatka_promoters): צבע, קוד בקישור, וסוג עלות
alter table public.harpatka_promoters add column if not exists color text not null default 'red';
alter table public.harpatka_promoters add column if not exists code text;
create unique index if not exists promoters_code on public.harpatka_promoters (code) where code is not null;
alter table public.harpatka_promoters add column if not exists cost_on_lead boolean not null default false;
alter table public.harpatka_promoters add column if not exists cost_from_payment boolean not null default false;

-- 5. טבלאות חדשות: העדפות מנהל, מדרגות מחיר, דרכי תשלום
create table if not exists public.harpatka_admin_prefs (
  email text primary key,
  sender_name text, wa_intro text, att_lead text, event_msg text, event_open text
);
create table if not exists public.harpatka_price_tiers (
  id uuid primary key default gen_random_uuid(),
  days int not null unique check (days >= 0),
  price int not null check (price >= 0)
);
create table if not exists public.harpatka_pay_methods (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  sort int not null default 1
);
do $$ declare t text; begin
  foreach t in array array['harpatka_admin_prefs', 'harpatka_price_tiers', 'harpatka_pay_methods'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "harpatka admin all" on public.%I', t);
    execute format('create policy "harpatka admin all" on public.%I for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin())', t);
    execute format('grant all on public.%I to authenticated, service_role', t);
  end loop;
end $$;

-- 6. נתוני התחלה
insert into public.harpatka_price_tiers (days, price) values (4, 80), (0, 100) on conflict (days) do nothing;
insert into public.harpatka_pay_methods (key, name, sort) values ('paybox', 'פייבוקס', 1), ('bit', 'ביט', 2), ('cash', 'מזומן', 3), ('bank', 'בנק', 4) on conflict (key) do nothing;

-- 7. הערות מערכת: גרסה שמכירה סטטוסים מותאמים, והערה על הפקדה
CREATE OR REPLACE FUNCTION public.harpatka_att_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$


declare os text; ns text;


begin


  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;


  if tg_op = 'INSERT' then


    if coalesce(new.attended, false) then


      perform public.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);


    else


      perform public.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id);


    end if;


  elsif tg_op = 'UPDATE' then


    os := public.harpatka_pay_status(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe); ns := public.harpatka_pay_status(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe);


    if old.status_key is not null then os := coalesce((select label from public.harpatka_statuses where key = old.status_key), os); end if;

    if new.status_key is not null then ns := coalesce((select label from public.harpatka_statuses where key = new.status_key), ns); end if;

    if os <> ns then


      perform public.harpatka_sys_note(new.participant_id, 'סטטוס למפגש ' || public.harpatka_meeting_short(new.meeting_id) || ': ' || ns


        || case when ns = 'שילם' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end


        || case when ns = 'שילם' and new.pay_method is not null then ' ב' || public.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end || ' (היה: ' || os || ')',


        'status_changed', new.meeting_id, coalesce(old.status_key, public.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe)), coalesce(new.status_key, public.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe)), case when ns = 'שילם' then new.paid_amount end, null, case when ns = 'שילם' then new.pay_method end);


    end if;


    if coalesce(old.attended, false) <> coalesce(new.attended, false) then


      perform public.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || public.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);


    end if;


    if (old.details_sent_at is null) <> (new.details_sent_at is null) then

      perform public.harpatka_sys_note(new.participant_id, case when new.details_sent_at is not null then 'נשלחו פרטי הערב (וואטסאפ) למפגש ' else 'סימון שליחת פרטי הערב בוטל למפגש ' end || public.harpatka_meeting_short(new.meeting_id),

        case when new.details_sent_at is not null then 'details_sent' else 'details_unsent' end, new.meeting_id);

    end if;

  elsif tg_op = 'DELETE' then


    perform public.harpatka_sys_note(old.participant_id, 'הוסר/ה מהמפגש ' || public.harpatka_meeting_short(old.meeting_id), 'meeting_removed', old.meeting_id);


  end if;


  return coalesce(new, old);


exception when others then return coalesce(new, old);


end $function$
;

drop trigger if exists harpatka_att_notes on public.harpatka_attendance;
create trigger harpatka_att_notes after insert or update of paid, exempt, pay_requested_at, will_pay, maybe, status_key, attended, details_sent_at or delete on public.harpatka_attendance
  for each row execute function public.harpatka_att_notes();
CREATE OR REPLACE FUNCTION public.harpatka_pay_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

  if new.kind = 'deposit' then

    perform public.harpatka_sys_note(new.participant_id,

      'התקבל תשלום ₪' || trim(to_char(new.amount, 'FM999990.##')) || coalesce(' ב' || public.harpatka_method_label(new.method, new.method_note), ''),

      'deposit', null, null, null, new.amount, null);

  end if;

  return null;

exception when others then return null;

end $function$
;

drop trigger if exists harpatka_pay_notes on public.harpatka_payments;
create trigger harpatka_pay_notes after insert on public.harpatka_payments for each row execute function public.harpatka_pay_notes();

-- 8. דרכי הגעה: קרן (עמלה קבועה על התשלום הראשון) ופייסבוק (עלות לליד, קוד p = ?s=p באתר)
update public.harpatka_promoters set code = 'k', color = 'red', cost_from_payment = true, cost_on_lead = false where name = 'קרן' and code is null;
insert into public.harpatka_promoters (name, rate_type, rate, color, code, cost_on_lead, cost_from_payment)
  select 'פייסבוק', 'fixed', 20, 'sky', 'p', true, false where not exists (select 1 from public.harpatka_promoters where code = 'p');
update public.harpatka_participants set source_code = 'p' where source = 'site-ad' and source_code is null;
update public.harpatka_participants p set promoter_id = pr.id from public.harpatka_promoters pr where pr.code = 'p' and p.source = 'site-ad' and p.promoter_id is null;

-- 9. שיוכי "חינם" מסומנים "לא משלם" (שאושר)
update public.harpatka_attendance set no_pay = true where exempt and no_pay is null;

notify pgrst, 'reload schema';
commit;
