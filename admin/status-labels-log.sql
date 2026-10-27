-- הערות מערכת על סטטוס מפגש: שמות הסטטוסים לפי המערכת (harpatka_statuses, כולל שמות ששונו בהגדרות) ולא שמות קבועים ישנים (שילם / בטיפול...).
-- בנוסף: שינוי "סטטוס אחרי המפגש" (after_key) נרשם בהערה. אידמפוטנטי; להריץ על public ואז admin/test-site.sql (מעתיק את הפונקציות ל-test).

-- שם הסטטוס לפי מפתח: מהטבלה, ואם אין (סטטוס שנמחק) שם ברירת המחדל הישן
create or replace function public.harpatka_status_label(k text) returns text
language sql stable security definer set search_path to 'public' as $$
  select coalesce(
    (select s.label from public.harpatka_statuses s where s.key = k),
    case k when 'paid' then 'שילם' when 'willpay' then 'ישלם' when 'exempt' then 'חינם' when 'maybe' then 'ספונטני' when 'requested' then 'בטיפול' when 'unpaid' then 'חדש' else k end
  )
$$;

create or replace function public.harpatka_att_notes() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare ok text; nk text;
begin
  if current_setting('harpatka.skip_note', true) = '1' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if coalesce(new.attended, false) then
      perform public.harpatka_sys_note(new.participant_id, 'הגיע/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id) || ' (ללא הרשמה מראש)', 'walk_in', new.meeting_id);
    else
      perform public.harpatka_sys_note(new.participant_id, 'שויך/ה למפגש ' || public.harpatka_meeting_label(new.meeting_id), 'meeting_linked', new.meeting_id);
    end if;
  elsif tg_op = 'UPDATE' then
    -- סטטוס לפני המפגש: משווים לפי המפתח, ומציגים את השם הנוכחי של הסטטוס
    ok := coalesce(old.status_key, public.harpatka_pay_code(old.paid, old.exempt, old.pay_requested_at, old.will_pay, old.maybe));
    nk := coalesce(new.status_key, public.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe));
    if ok <> nk then
      perform public.harpatka_sys_note(new.participant_id,
        'סטטוס למפגש ' || public.harpatka_meeting_short(new.meeting_id) || ': ' || public.harpatka_status_label(nk)
          || case when nk = 'paid' and new.paid_amount is not null then ' ₪' || trim(to_char(new.paid_amount, 'FM999990.##')) else '' end
          || case when nk = 'paid' and new.pay_method is not null then ' ב' || public.harpatka_method_label(new.pay_method, new.pay_method_note) else '' end
          || ' (היה: ' || public.harpatka_status_label(ok) || ')',
        'status_changed', new.meeting_id, ok, nk, case when nk = 'paid' then new.paid_amount end, null, case when nk = 'paid' then new.pay_method end);
    end if;
    -- סטטוס אחרי המפגש
    if new.after_key is distinct from old.after_key then
      perform public.harpatka_sys_note(new.participant_id,
        'סטטוס אחרי המפגש ' || public.harpatka_meeting_short(new.meeting_id) || ': ' || coalesce(public.harpatka_status_label(new.after_key), 'ללא') || ' (היה: ' || coalesce(public.harpatka_status_label(old.after_key), 'ללא') || ')',
        'after_status_changed', new.meeting_id, old.after_key, new.after_key);
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
end $fn$;

-- הטריגר חייב להאזין גם לשינוי after_key (סטטוס אחרי המפגש), אחרת השינוי לא נרשם
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('drop trigger if exists harpatka_att_notes on %I.harpatka_attendance', s);
    execute format('create trigger harpatka_att_notes after insert or delete or update of paid, exempt, pay_requested_at, will_pay, maybe, status_key, after_key, attended, details_sent_at on %I.harpatka_attendance for each row execute function %I.harpatka_att_notes()', s, s);
  end loop;
end $$;
