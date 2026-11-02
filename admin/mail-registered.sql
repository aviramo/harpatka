-- מייל למשתתף ברגע ההרשמה למפגש: נרשמת, ונשאר לשלם (2.11.26). מריצים אחרי mail-log.sql. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/mail-registered.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/mail-registered.sql | supabase db query --linked
-- * נשלח בכל הרשמה של המשתתף עצמו, גם לפני שהשלים פרטים (בלי שם: הפנייה לפי השם בחשבון הגוגל). לא כשמנהל רושם משתתף אחר, לא במפגש שעבר ולא במפגש "לא לתשלום".
-- * טריגר דחוי: רץ בסוף הפעולה, אחרי שהחשבון כבר מחובר, ולכן יש לאן לשלוח. בלי חשבון גוגל: "המייל לא נשלח" בהערת ההרשמה, כמו בכל מייל.
-- * harpatka_me_phone: קודם מחברים את החשבון למשתתף, ורק אחר כך נרשמים למפגש.
insert into __S__.harpatka_mail_templates (key, subject, html) values ('meeting_registered', 'נרשמת למפגש, נשאר לשלם', $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D">
<div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D">
<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>יוצאים להרפתקה</div></div>
<div style="padding:16px 4px 24px">
<div style="font-size:20px;font-weight:bold;color:#2C231D;margin-bottom:12px">{{hello}}</div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">נרשמת למפגש:</div>
{{{meeting_block}}}
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-bottom:16px">המקום נשמר זמנית, והוא יישמר קבוע רק אחרי התשלום.{{{price_note}}}</div>
{{{credit_block}}}
<a href="{{me_link}}" style="display:block;background:#C8411B;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:0">{{pay_label}}</a>
<div style="font-size:15px;line-height:1.6;color:#4A3D33;margin-top:18px">שאלות או שינויים? אפשר לכתוב לנו בוואטסאפ: <span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span></div>
<div style="font-size:16px;line-height:1.6;color:#2C231D;margin-top:18px">נתראה, אופיר והדר</div>
</div></div></div>$tpl$)
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

create or replace function __S__.harpatka_reg_user_mail_fn() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare
  mt __S__.harpatka_meetings; v jsonb; gn text; price int; nx jsonb; lft int;
  em text := lower(coalesce(auth.jwt() ->> 'email', ''));
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  note text := '';
begin
  if coalesce(new.no_pay, false) then return null; end if;
  if em <> '' and exists (select 1 from public.harpatka_admins a where lower(a.email) = em)
     and not exists (select 1 from __S__.harpatka_members x where x.user_id = auth.uid() and x.participant_id = new.participant_id) then return null; end if;   -- מנהל שרשם משתתף אחר: בלי מייל
  select * into mt from __S__.harpatka_meetings where id = new.meeting_id;
  if not found or mt.meeting_date < today then return null; end if;
  lft := mt.meeting_date - today;
  price := __S__.harpatka_meeting_price(mt.price_tiers, lft);
  -- המדרגה הבאה, כדי שהסכום במייל לא יטעה כשהמחיר עולה
  select e into nx from jsonb_array_elements(case when jsonb_typeof(mt.price_tiers -> 'steps') = 'array' then mt.price_tiers -> 'steps' else '[]'::jsonb end) e
    where (e ->> 'days')::int < lft order by (e ->> 'days')::int desc limit 1;
  if nx is not null and (nx ->> 'price')::int > coalesce(price, 0) then
    note := ' המחיר עולה ל-₪' || (nx ->> 'price') || ' ב-' || to_char(mt.meeting_date - (nx ->> 'days')::int, 'FMDD.FMMM') || '.';
  end if;
  v := __S__.harpatka_mail_common(new.participant_id, new.meeting_id);
  if v ->> 'hello' = 'שלום,' then   -- עוד לא השלים פרטים: השם מחשבון הגוגל
    select split_part(btrim(m.google_name), ' ', 1) into gn from __S__.harpatka_members m where m.participant_id = new.participant_id and coalesce(m.google_name, '') <> '' order by (m.status = 'approved') desc limit 1;
    if coalesce(gn, '') <> '' then v := v || jsonb_build_object('hello', 'שלום ' || gn || ','); end if;
  end if;
  perform __S__.harpatka_mail_participant('meeting_registered', new.participant_id, v || jsonb_build_object(
    'me_link', 'https://harpatka.co.il/me/?m=' || new.meeting_id,
    'pay_label', case when price is null then 'לתשלום' else 'לתשלום ₪' || price end,
    'price_note', note));
  return null;
exception when others then return null;   -- כשל במייל לא מבטל את ההרשמה
end $f$;
revoke all on function __S__.harpatka_reg_user_mail_fn() from public, anon, authenticated;
drop trigger if exists harpatka_reg_user_mail on __S__.harpatka_attendance;
create constraint trigger harpatka_reg_user_mail after insert on __S__.harpatka_attendance deferrable initially deferred for each row execute function __S__.harpatka_reg_user_mail_fn();

-- harpatka_me_phone: חיבור החשבון לפני ההרשמה
do $do$
declare d text; a int; b int; c int; blk text; mark text := E'  -- ההרשמה למפגש כבר עכשיו';
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me_phone';
  if d is null then raise exception 'harpatka_me_phone not found'; end if;
  a := position(E'  -- חיבור חשבון הגוגל למשתתף' in d);
  c := position(mark in d);
  if a = 0 or c = 0 then raise exception 'harpatka_me_phone markers not found'; end if;
  if a > c then   -- עוד לא הוחל
    b := position(E'  select * into pa from __S__.harpatka_participants where id = pid;\n  return jsonb_build_object(' in d);
    if b = 0 or b < a then raise exception 'harpatka_me_phone end marker not found'; end if;
    blk := substr(d, a, b - a);
    d := substr(d, 1, a - 1) || substr(d, b);
    d := substr(d, 1, c - 1) || blk || substr(d, c);
    execute d;
  end if;
end $do$;
notify pgrst, 'reload schema';
