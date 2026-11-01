-- מייל "הרשמה חדשה" למנהלים רק אחרי שהמשתתף השלים את הפרטים (שם פרטי, שם משפחה, גיל ומגדר). מריצים פעם ב-test ופעם ב-public (להחליף __S__ בשם הסכמה). אידמפוטנטי.
-- * harpatka_me_phone: משתתף חדש שנוצר עם טלפון בלבד לא שולח מייל. משתתף לא פעיל שחזר ויש לו פרטים: מייל עם הפרטים שלו.
-- * טריגר על המשתתף: כשהפרטים הושלמו (בפופאפ ההרשמה או באזור האישי) נשלח המייל, עם המפגש האחרון שנרשם אליו.
--   לא כשמנהל ממלא פרטים של משתתף אחר (דף הניהול או צפייה כמשתתף).
-- * harpatka_att_reg_mail: הרשמה למפגש של משתתף בלי פרטים לא שולחת מייל (המייל יישלח בהשלמה).
-- * טופס ההרשמה הרגיל (harpatka_signup, למשל מפייסבוק ואינסטגרם) כולל את כל הפרטים והמייל נשלח מיד. מי שעצר קודם אחרי הטלפון וממלא עכשיו את הטופס: הפרטים נשמרים על המשתתף שלו, והטריגר שולח את המייל.
-- * תיקון כפילות: משתתף שנוצר בתוך בלוק exception נכתב ב-subtransaction, ולכן xmin לא היה שווה ל-txid_current והבדיקה "נוצר בפעולה הזו" נכשלה: נשלחו גם "הרשמה חדשה" וגם "הרשמה למפגש". עכשיו בודקים אם מי שכתב את השורה עדיין בתהליך, וזה רק הטרנזקציה שלנו.

create or replace function __S__.harpatka_details_done(p_first text, p_last text, p_age int, p_gender text) returns boolean
language sql immutable as $f$
  select char_length(btrim(coalesce(p_first, ''))) >= 2 and char_length(btrim(coalesce(p_last, ''))) >= 2 and p_age is not null and p_gender is not null
$f$;

create or replace function __S__.harpatka_participant_completed() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare em text; mid uuid; md date; mt time;
begin
  if __S__.harpatka_details_done(old.first_name, old.last_name, old.age, old.gender) or not __S__.harpatka_details_done(new.first_name, new.last_name, new.age, new.gender) then return new; end if;
  em := lower(coalesce(auth.jwt() ->> 'email', ''));
  if em <> '' and exists (select 1 from public.harpatka_admins a where lower(a.email) = em)
     and not exists (select 1 from __S__.harpatka_members x where x.user_id = auth.uid() and x.participant_id = new.id) then return new; end if;   -- מנהל שממלא פרטים של משתתף אחר: בלי מייל
  select a.meeting_id, m.meeting_date, m.meeting_time into mid, md, mt from __S__.harpatka_attendance a join __S__.harpatka_meetings m on m.id = a.meeting_id
    where a.participant_id = new.id order by a.created_at desc limit 1;
  perform __S__.harpatka_notify_signup(btrim(new.first_name || ' ' || new.last_name), coalesce(nullif(new.phone_norm, ''), new.phone), new.age, md, mt, new.id, mid, new.gender);
  return new;
exception when others then return new;   -- תקלה במייל לא פוגעת בשמירה
end $f$;
revoke all on function __S__.harpatka_participant_completed() from public, anon, authenticated;
drop trigger if exists harpatka_participant_completed on __S__.harpatka_participants;
create trigger harpatka_participant_completed after update of first_name, last_name, age, gender on __S__.harpatka_participants for each row execute function __S__.harpatka_participant_completed();

do $do$
declare
  d text; q text[];
  pairs text[][] := array[
    ['harpatka_me_phone',
     'if created or react then perform __S__.harpatka_notify_signup(disp, norm, null, md, mt, pid, mid, null); end if;',
     'if react then select * into pa from __S__.harpatka_participants where id = pid; if __S__.harpatka_details_done(pa.first_name, pa.last_name, pa.age, pa.gender) then perform __S__.harpatka_notify_signup(btrim(pa.first_name || '' '' || pa.last_name), norm, pa.age, md, mt, pid, mid, pa.gender); end if; end if;'],
    ['harpatka_att_reg_mail',
     'if p.id is null then return new; end if;',
     'if p.id is null or not __S__.harpatka_details_done(p.first_name, p.last_name, p.age, p.gender) then return new; end if;'],
    ['harpatka_att_reg_mail',
     'if p.xm = (txid_current() % 4294967296)::text then return new; end if;',
     'if txid_status(((txid_current() >> 32) << 32) + p.xm::bigint) = ''in progress'' then return new; end if;'],
    ['harpatka_signup',
     'if res = ''created'' then',
     'update __S__.harpatka_participants set first_name = fn, last_name = ln, age = p_age, age_set_at = current_date, gender = p_gender where id = pid and not __S__.harpatka_details_done(first_name, last_name, age, gender); if res = ''created'' and not found then']
  ];
begin
  foreach q slice 1 in array pairs loop
    select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = q[1];
    if position(q[3] in d) = 0 then
      if position(q[2] in d) = 0 then raise exception '% patch did not apply: %', q[1], q[2]; end if;
      execute replace(d, q[2], q[3]);
    end if;
  end loop;
end $do$;
