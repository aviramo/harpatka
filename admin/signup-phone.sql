-- שלב הטלפון לאורח (11.11.26): מי שמזין טלפון של משתתף קיים עם פרטים מלאים נרשם למפגש בלי למלא פרטים.
-- מחזירה json: status = 'created' / 'exists' (נרשם, ועם age לבדיקת טווח התשלום), 'need_details' (אין משתתף או חסרים פרטים: ממשיכים לשאר השדות), 'invalid_phone'.
-- חושפת למי שמנסה מספר אם הוא רשום (פשרה מודעת, כמו בלוח השיתופים ובחיבור לאזור האישי).
create or replace function __S__.harpatka_signup_phone(p_phone text, p_meeting uuid default null, p_src text default null, p_token uuid default null)
returns jsonb language plpgsql security definer set search_path = __S__, public as $$
declare n text; pa __S__.harpatka_participants; r text;
begin
  n := __S__.harpatka_normalize_phone(p_phone);
  if n is null or n = '' then return jsonb_build_object('status', 'invalid_phone'); end if;
  select * into pa from __S__.harpatka_participants where phone_norm = n order by active desc, created_at limit 1;
  if not found or coalesce(trim(pa.first_name), '') = '' or coalesce(trim(pa.last_name), '') = '' or pa.age is null or coalesce(pa.gender, '') = '' then return jsonb_build_object('status', 'need_details'); end if;
  r := __S__.harpatka_signup(p_phone => p_phone, p_age => pa.age, p_gender => pa.gender, p_src => p_src, p_first => pa.first_name, p_last => pa.last_name, p_meeting => p_meeting, p_token => null);
  return jsonb_build_object('status', r, 'age', pa.age);
end $$;
revoke all on function __S__.harpatka_signup_phone(text, uuid, text, uuid) from public;
grant execute on function __S__.harpatka_signup_phone(text, uuid, text, uuid) to anon, authenticated;
