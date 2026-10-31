-- סטטוס מפגש: איחוד "במפגש" ו"אחרי המפגש" לרשימה אחת (31.10.26). "לפני המפגש" נקרא בממשק "סטטוס הרשמה".
-- לכל שיוך משתתף-מפגש סטטוס מפגש אחד (העמודה meeting_key), כמו סטטוס ההרשמה: בחירה בסטטוס אחר מחליפה אותו.
-- מי שהיה לו גם סטטוס "במפגש" וגם "אחרי המפגש" מקבל את זה של "אחרי המפגש" (הוא דרס את הראשון גם קודם).
-- העמודות הישנות during_key ו-after_key נשארות קפואות (היסטוריה ורולבק), בלי כתיבה חדשה.
-- אידמפוטנטי. להריץ על test ועל public (החלפת __S__):  sed 's/__S__/public/g' admin/meeting-statuses-merge.sql | supabase db query --linked
drop trigger if exists harpatka_att_notes on __S__.harpatka_attendance;
alter table __S__.harpatka_attendance drop column if exists meeting_keys;   -- ניסוי קודם (מערך), רק בבדיקות
alter table __S__.harpatka_attendance add column if not exists meeting_key text;

-- העברת הסטטוסים הקיימים: "אחרי המפגש" גובר על "במפגש"; בלי הערות מערכת
do $m$ begin
  perform set_config('harpatka.skip_note', '1', true);
  update __S__.harpatka_attendance set meeting_key = coalesce(after_key, during_key)
   where meeting_key is null and (during_key is not null or after_key is not null);
end $m$;

-- הסטטוסים עצמם: שלב אחד "meeting", בסדר שבו הם היו (קודם "במפגש" ואחריו "אחרי המפגש"), ממוספר מחדש לכל סוג מפגש
with ord as (
  select key, row_number() over (partition by coalesce(type_id, '00000000-0000-0000-0000-000000000000'::uuid) order by case phase when 'during' then 0 else 1 end, sort, key) as rn
    from __S__.harpatka_statuses where scope <> 'participant' and phase in ('during', 'after')
)
update __S__.harpatka_statuses s set phase = 'meeting', sort = ord.rn from ord where s.key = ord.key;

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
    if new.meeting_key is not null then
      perform __S__.harpatka_sys_note(new.participant_id, 'סטטוס מפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(__S__.harpatka_status_label(new.meeting_key), new.meeting_key) || ' (היה: ללא)', 'meeting_status_changed', new.meeting_id, null, new.meeting_key);
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
    -- סטטוס מפגש (אחד לכל משתתף, כמו סטטוס ההרשמה)
    if new.meeting_key is distinct from old.meeting_key then
      perform __S__.harpatka_sys_note(new.participant_id,
        'סטטוס מפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(__S__.harpatka_status_label(new.meeting_key), 'ללא') || ' (היה: ' || coalesce(__S__.harpatka_status_label(old.meeting_key), 'ללא') || ')',
        'meeting_status_changed', new.meeting_id, old.meeting_key, new.meeting_key);
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
create trigger harpatka_att_notes after insert or delete or update of paid, exempt, pay_requested_at, will_pay, maybe, status_key, meeting_key, attended, details_sent_at, no_pay on __S__.harpatka_attendance for each row execute function __S__.harpatka_att_notes();

notify pgrst, 'reload schema';
