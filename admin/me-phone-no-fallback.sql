-- harpatka_me_phone (חשבון גוגל מזין טלפון) כבר לא רושם למפגש "הקרוב" כשלא נשלח מפגש (1.11.26).
-- הסיבה: כשהדף לא הצליח לטעון את המפגש הקרוב, הפופאפ הציג "השארת פרטים" אבל השרת רשם למפגש בכל זאת (ללא ידיעת המשתתף).
-- עכשיו נרשמים רק כשנשלח p_meeting (מפגש שעוד לא עבר; אם הוא עבר, הקרוב). בלי p_meeting: רק חיבור החשבון, כמו p_no_meeting.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public:  sed 's/__S__/test/g' admin/me-phone-no-fallback.sql | supabase db query --linked
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = '__S__' and p.proname = 'harpatka_me_phone';
  if d is null then raise exception 'harpatka_me_phone not found'; end if;
  if d like '%and p_meeting is not null then%' then return; end if;   -- כבר הוחל
  d := replace(d, E'  if not coalesce(p_no_meeting, false) then\n    if p_meeting is not null then',
                  E'  if not coalesce(p_no_meeting, false) and p_meeting is not null then   -- נשלח מפגש: נרשמים אליו (או לקרוב אם הוא כבר עבר); בלי מפגש: רק חיבור\n    if p_meeting is not null then');
  d := replace(d, 'case when coalesce(p_no_meeting, false) then '' (בלי שיוך למפגש)'' else '' (אין מפגש קרוב)'' end',
                  'case when coalesce(p_no_meeting, false) or p_meeting is null then '' (בלי שיוך למפגש)'' else '' (אין מפגש קרוב)'' end');
  if d not like '%and p_meeting is not null then%' or d not like '%or p_meeting is null then%' then raise exception 'patch did not apply'; end if;
  execute d;
end $$;
notify pgrst, 'reload schema';
