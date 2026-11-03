-- תגיות במקום סטטוסים, וסימון הגעה בשדה נפרד (3.11.26).
-- להריץ עם החלפה: sed 's/__S__/test/g' admin/labels-arrival.sql > x.sql ואז supabase db query --linked -f x.sql
-- על public: רק בקידום, אחרי גיבוי (מוחק סטטוסים ומעדכן שיוכים קיימים). ההעברה רצה פעם אחת: כל עוד קיים אחד מהסטטוסים שנמחקים.
--
-- מי הגיע: מי שהיה בסטטוס "הגיע", וגם מי שהיה בסטטוס "יצא" (הגיע ויצא). "שוריין" לא אומר שהגיע.
-- תגית אחת לכל שיוך (status_key): נשארות רק "בטיפול" ו"יצא". שוריין, חדש והגיע נמחקים, ומי שהיה בהם נשאר בלי תגית.
-- תשלום בהמשך (pay_later_at): המשתתף משוריין למפגש, והתשלום נשאר פתוח.
-- העמודות הישנות (paid, will_pay, maybe, exempt, meeting_key, during_key, after_key, points, status_lead, tags) נשארות בלי שימוש.

begin;

alter table __S__.harpatka_attendance add column if not exists pay_later_at timestamptz;

do $$
begin
  if exists (select 1 from __S__.harpatka_statuses where key in ('paid', 'unpaid', 'arrived')) then
    perform set_config('harpatka.skip_note', '1', true);   -- העברת נתונים: בלי הערות מערכת

    update __S__.harpatka_attendance a set attended = true,
      attended_at = coalesce(a.attended_at, (select (m.meeting_date + m.meeting_time) at time zone 'Asia/Jerusalem' from __S__.harpatka_meetings m where m.id = a.meeting_id))
      where a.meeting_key in ('arrived', 'm_left') and not coalesce(a.attended, false);

    -- בטיפול: עד עכשיו סומן בעמודה pay_requested_at, ורק כשלא היה סטטוס אחר שגובר עליו
    update __S__.harpatka_attendance set status_key = 'requested'
      where status_key is null and pay_requested_at is not null and not coalesce(paid, false) and not coalesce(exempt, false) and not coalesce(will_pay, false) and not coalesce(maybe, false);

    -- יצא: עובר מעמודת סטטוס המפגש לתגית
    update __S__.harpatka_attendance set status_key = 'm_left' where meeting_key = 'm_left';

    update __S__.harpatka_attendance set status_key = null where status_key is not null and status_key not in ('requested', 'm_left');

    delete from __S__.harpatka_statuses where key not in ('requested', 'm_left');
    update __S__.harpatka_statuses set phase = 'before', sort = case key when 'requested' then 1 else 2 end;
  end if;
end $$;

-- הערות מערכת: תגית אחת, והגעה בנפרד
create or replace function __S__.harpatka_att_notes()
 returns trigger
 language plpgsql
 security definer
 set search_path to '__S__'
as $function$
begin
  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if coalesce(new.attended, false) then
      perform __S__.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || __S__.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);
    else
      perform __S__.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || __S__.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id, null, new.status_key);
    end if;
  elsif tg_op = 'UPDATE' then
    if new.status_key is distinct from old.status_key then
      perform __S__.harpatka_sys_note(new.participant_id,
        'תגית למפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(__S__.harpatka_status_label(new.status_key), 'בלי תגית')
          || ' (היה: ' || coalesce(__S__.harpatka_status_label(old.status_key), 'בלי תגית') || ')',
        'status_changed', new.meeting_id, old.status_key, new.status_key);
    end if;
    if coalesce(old.attended, false) <> coalesce(new.attended, false) then
      perform __S__.harpatka_sys_note(new.participant_id, case when new.attended then 'הגיע/ה למפגש ' else 'סימון ההגעה בוטל למפגש ' end || __S__.harpatka_meeting_short(new.meeting_id), case when new.attended then 'attended' else 'attendance_cancelled' end, new.meeting_id);
    end if;
    if coalesce(old.no_pay, false) <> coalesce(new.no_pay, false) and new.pay_closed_at is null and old.pay_closed_at is null then   -- סימון "לא לתשלום" במסך ההקצאה
      perform __S__.harpatka_sys_note(new.participant_id, case when coalesce(new.no_pay, false) then 'המפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ' סומן לא לתשלום' else 'חזרה לתשלום למפגש ' || __S__.harpatka_meeting_short(new.meeting_id) end,
        case when coalesce(new.no_pay, false) then 'free_on' else 'free_off' end, new.meeting_id);
    end if;
    if (old.pay_later_at is null) <> (new.pay_later_at is null) and not (new.pay_later_at is null and coalesce(new.no_pay, false)) then   -- מעבר ל"לא לתשלום" כבר נרשם בהערה משלו
      perform __S__.harpatka_sys_note(new.participant_id, case when new.pay_later_at is not null then 'המפגש ' || __S__.harpatka_meeting_short(new.meeting_id) || ' סומן תשלום בהמשך' else 'בוטל תשלום בהמשך למפגש ' || __S__.harpatka_meeting_short(new.meeting_id) end,
        case when new.pay_later_at is not null then 'pay_later_on' else 'pay_later_off' end, new.meeting_id);
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
create trigger harpatka_att_notes after insert or delete or update of status_key, attended, details_sent_at, no_pay, pay_later_at on __S__.harpatka_attendance
  for each row execute function __S__.harpatka_att_notes();

commit;
