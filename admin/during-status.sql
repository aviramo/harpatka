-- סטטוס "במפגש" (31.10.26): שלב שלישי של סטטוס מפגש, בין "לפני המפגש" ל"אחרי המפגש". עוקף את "לפני" ונדרס על ידי "אחרי".
-- מחליף את שדה ההגעה (הגיע / לא הגיע): הסטטוס "הגיע" (מפתח arrived) הוא סטטוס מערכת משותף לכל הסוגים, ומי שסומן שהגיע קיבל אותו.
-- העמודה attended נשארת כמראה מחושבת (טריגר) כדי שהפונקציות הקיימות (אזור אישי, סטטיסטיקות, הערות) ימשיכו לעבוד.
-- אידמפוטנטי. להריץ על public ועל test (החלפת __S__):  sed 's/__S__/public/g' admin/during-status.sql | supabase db query --linked   (וגם עם test)
alter table __S__.harpatka_attendance add column if not exists during_key text;
insert into __S__.harpatka_statuses (key, label, color, sort, scope, phase)
values ('arrived', 'הגיע', 'green', 0, 'meeting', 'during')
on conflict (key) do nothing;

-- המראה: attended נגזר מ-during_key (ובכיוון ההפוך, לכתיבה ישנה של attended בלבד)
create or replace function __S__.harpatka_att_during_mirror() returns trigger language plpgsql as $f$
begin
  if tg_op = 'UPDATE' and new.during_key is not distinct from old.during_key and coalesce(new.attended, false) is distinct from coalesce(old.attended, false) then
    if new.attended then new.during_key := 'arrived'; elsif new.during_key = 'arrived' then new.during_key := null; end if;
  elsif tg_op = 'INSERT' and coalesce(new.attended, false) and new.during_key is null then
    new.during_key := 'arrived';
  end if;
  new.attended := coalesce(new.during_key = 'arrived', false);
  if new.attended then
    new.attended_at := case when tg_op = 'UPDATE' and coalesce(old.attended, false) then coalesce(old.attended_at, now()) else coalesce(new.attended_at, now()) end;
  else
    new.attended_at := null;
  end if;
  return new;
end $f$;
drop trigger if exists harpatka_att_during_mirror on __S__.harpatka_attendance;
create trigger harpatka_att_during_mirror before insert or update on __S__.harpatka_attendance for each row execute function __S__.harpatka_att_during_mirror();

-- מי שסומן שהגיע מקבל את הסטטוס "הגיע" (בלי הערות מערכת)
do $m$ begin
  perform set_config('harpatka.skip_note', '1', true);
  update __S__.harpatka_attendance set during_key = 'arrived' where attended and during_key is distinct from 'arrived';
end $m$;

create or replace function __S__.harpatka_att_notes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO '__S__'
AS $function$
declare ok text; nk text;
begin
  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if coalesce(new.attended, false) then
      perform __S__.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || __S__.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);
    else
      perform __S__.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || __S__.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id);
    end if;
  elsif tg_op = 'UPDATE' then
    -- סטטוס לפני המפגש: משווים לפי המפתח, ומציגים את השם הנוכחי של הסטטוס
    ok := coalesce(old.status_key, __S__.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe));
    nk := coalesce(new.status_key, __S__.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe));
    if ok <> nk then
      perform __S__.harpatka_sys_note(new.participant_id,
        'סטטוס למפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || __S__.harpatka_status_label(nk)
          || ' (היה: ' || __S__.harpatka_status_label(ok) || ')',
        'status_changed', new.meeting_id, ok, nk);
    end if;
    -- סטטוס אחרי המפגש
    if new.after_key is distinct from old.after_key then
      perform __S__.harpatka_sys_note(new.participant_id,
        'סטטוס אחרי המפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(__S__.harpatka_status_label(new.after_key), 'ללא') || ' (היה: ' || coalesce(__S__.harpatka_status_label(old.after_key), 'ללא') || ')',
        'after_status_changed', new.meeting_id, old.after_key, new.after_key);
    end if;
    -- סטטוס במפגש (חוץ ממעבר ריק <-> "הגיע", שנרשם כהערת הגעה)
    if new.during_key is distinct from old.during_key and not ((old.during_key is null and new.during_key = 'arrived') or (old.during_key = 'arrived' and new.during_key is null)) then
      perform __S__.harpatka_sys_note(new.participant_id,
        'סטטוס במפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(__S__.harpatka_status_label(new.during_key), 'ללא') || ' (היה: ' || coalesce(__S__.harpatka_status_label(old.during_key), 'ללא') || ')',
        'during_status_changed', new.meeting_id, old.during_key, new.during_key);
    end if;
    if coalesce(old.attended, false) <> coalesce(new.attended, false) then
      perform __S__.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || __S__.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);
    end if;
    if coalesce(old.no_pay, false) <> coalesce(new.no_pay, false) then   -- סימון "חינם" במסך ההקצאה
      perform __S__.harpatka_sys_note(new.participant_id, case when coalesce(new.no_pay, false) then 'המפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ' סומן כחינם' else 'החינם בוטל למפגש ' || __S__.harpatka_meeting_short(new.meeting_id) end,
        case when coalesce(new.no_pay, false) then 'free_on' else 'free_off' end, new.meeting_id);
    end if;
    if (old.details_sent_at is null) <> (new.details_sent_at is null) then
      perform __S__.harpatka_sys_note(new.participant_id, case when new.details_sent_at is not null then 'נשלחו פרטי הערב (וואטסאפ) למפגש ' else 'סימון שליחת פרטי הערב בוטל למפגש ' end || __S__.harpatka_meeting_short(new.meeting_id),
        case when new.details_sent_at is not null then 'details_sent' else 'details_unsent' end, new.meeting_id);
    end if;
  elsif tg_op = 'DELETE' then
    perform __S__.harpatka_sys_note(old.participant_id, 'הוסר/ה מהמפגש ' || __S__.harpatka_meeting_short(old.meeting_id), 'meeting_removed', old.meeting_id);
  end if;
  return coalesce(new, old);
exception when others then return coalesce(new, old);
end $function$;
drop trigger if exists harpatka_att_notes on __S__.harpatka_attendance;
create trigger harpatka_att_notes after insert or delete or update of paid, exempt, pay_requested_at, will_pay, maybe, status_key, after_key, during_key, attended, details_sent_at, no_pay on __S__.harpatka_attendance for each row execute function __S__.harpatka_att_notes();

notify pgrst, 'reload schema';
