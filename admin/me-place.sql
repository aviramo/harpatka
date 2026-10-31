-- האזור האישי: לכל מפגש גם המיקום (harpatka_meetings.place), כדי להציג "שם המפגש · מיקום" (31.10.26).
-- אותה פונקציה בדיוק כמו בבסיס הנתונים, רק עם השדה place ברשימת המפגשים. אידמפוטנטי. בקידום: אחרי meeting-place.sql.
-- בסביבת הבדיקות הפונקציה שונה מעט (harpatka_is_admin_site), ולכן שם היא עודכנה ישירות מההגדרה שלה.

CREATE OR REPLACE FUNCTION public.harpatka_me(p_as uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid uuid := auth.uid();
  adm boolean := public.harpatka_is_admin();
  m public.harpatka_members;
  pid uuid;
  pa public.harpatka_participants;
  imp boolean := false;
  bal numeric := 0;
  nxt public.harpatka_meetings;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  meetings jsonb;
  nxt_json jsonb := null;
  price numeric;
begin
  if uid is null then raise exception 'auth'; end if;
  if p_as is not null then
    if not adm then raise exception 'forbidden'; end if;
    pid := p_as; imp := true;
  else
    select * into m from public.harpatka_members where user_id = uid;
    if not found then return jsonb_build_object('status', 'none', 'admin', adm); end if;
    if m.status = 'blocked' or m.status = 'removed' then return jsonb_build_object('status', 'blocked', 'admin', adm); end if;
    if m.status <> 'approved' or m.participant_id is null then
      return jsonb_build_object('status', case when m.participant_id is null then 'none' else 'pending' end, 'admin', adm);
    end if;
    pid := m.participant_id;
  end if;
  -- משתתף שהוסר (לא פעיל) שחוזר וניכנס לאזור האישי (חיבור מאושר, לא חסום) חוזר לפעילות; רק חסומים לא יכולים (נחסמו למעלה)
  if p_as is null and exists (select 1 from public.harpatka_participants where id = pid and not active) then
    update public.harpatka_participants set active = true where id = pid;
    begin perform public.harpatka_sys_note(pid, 'חזר/ה לפעילות דרך האזור האישי', 'reactivated'); exception when others then null; end;
  end if;
  select * into pa from public.harpatka_participants where id = pid and active;
  if not found then return jsonb_build_object('status', 'none', 'admin', adm); end if;

  select coalesce(sum(case when kind in ('credit', 'deposit') then amount
                           when kind in ('payment', 'refund') and coalesce(from_credit, false) then -amount else 0 end), 0)
    into bal from public.harpatka_payments where participant_id = pid;

  -- כל המפגשים שרלוונטיים למשתתף: כל מפגש עתידי (רשום או לא, עם מחיר לפי המדרגות של אותו מפגש) ומפגשים שעברו שהוא היה רשום אליהם
  select coalesce(jsonb_agg(x order by (x->>'date')), '[]'::jsonb) into meetings from (
    select jsonb_build_object(
      'id', mt.id, 'date', mt.meeting_date, 'time', to_char(mt.meeting_time, 'HH24:MI'), 'directions', mt.directions, 'name', mt.name, 'city', mt.city, 'place', mt.place,
      'registered', a.participant_id is not null,
      'reported', a.pay_reported_at is not null,
      'rejected', a.pay_rejected_at is not null and a.pay_reported_at is null,
      'attended', coalesce(a.attended, false), 'free', coalesce(a.no_pay, false),
      'paid', coalesce((select sum(case when p.kind = 'payment' then p.amount when p.kind = 'credit' or (p.kind = 'refund' and not coalesce(p.from_credit, false)) then -p.amount else 0 end)
                         from public.harpatka_payments p where p.participant_id = pid and p.meeting_id = mt.id), 0),
      'future', mt.meeting_date >= today,
      'price', case when mt.meeting_date >= today then public.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today) end) as x
    from public.harpatka_meetings mt left join public.harpatka_attendance a on a.meeting_id = mt.id and a.participant_id = pid
    where mt.meeting_date >= today or a.participant_id is not null
  ) s;

  select * into nxt from public.harpatka_meetings where meeting_date >= today order by meeting_date, meeting_time limit 1;
  if found then
    -- מדרגות המחיר של המפגש עצמו (עמודה price_tiers = {base, steps}): המדרגה שמתחילה הכי קרוב למפגש מבין אלה שכבר התחילו, אחרת המחיר הרגיל
    declare lft int := nxt.meeting_date - today; pt jsonb := coalesce(nxt.price_tiers, '{"base": 80, "steps": [{"days": 3, "price": 100}]}'::jsonb);
    begin
      if jsonb_typeof(pt) = 'object' then
        begin
          select (e->>'price')::int into price from jsonb_array_elements(coalesce(pt->'steps', '[]'::jsonb)) e where lft <= (e->>'days')::int order by (e->>'days')::int asc limit 1;
          if price is null then price := (pt->>'base')::int; end if;
        end;
      end if;
    end;
    nxt_json := jsonb_build_object('id', nxt.id, 'date', nxt.meeting_date, 'time', to_char(nxt.meeting_time, 'HH24:MI'), 'directions', nxt.directions, 'price', price,
      'registered', exists (select 1 from public.harpatka_attendance where participant_id = pid and meeting_id = nxt.id));
  end if;

  return jsonb_build_object('status', 'ok', 'admin', adm, 'impersonating', imp,
    'participant', jsonb_build_object('id', pa.id, 'first_name', pa.first_name, 'last_name', pa.last_name, 'phone', pa.phone,
      'age', case when pa.age is null then null else pa.age + (extract(year from age(today, pa.age_set_at)))::int end, 'gender', pa.gender),
    'balance', bal, 'meetings', meetings, 'next', nxt_json);
end $function$;

notify pgrst, 'reload schema';
