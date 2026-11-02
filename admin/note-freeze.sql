-- מה שנכתב בהערה לא משתנה (2.11.26). אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/note-freeze.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/note-freeze.sql | supabase db query --linked
-- * בכל הערה נשמרים ברגע שהיא נוצרת: איזה סטטוס (new_status), השם והצבע שלו (status_label, status_color), תאריך המפגש (meeting_short) והשם של מי שביצע (author_name).
-- * התצוגה נלקחת רק מההערה: שינוי או מחיקה של סטטוס, מנהל או מפגש לא משנים הערה שכבר נכתבה. בשיוך למפגש (meeting_linked) הסטטוס עד עכשיו חושב בתצוגה מהנתונים הנוכחיים, ולכן השתנה אחרי הסרה.
-- * הערות קיימות: בשיוך, הסטטוס מיומן הביקורת, אחרת מהשינוי הראשון אחריו, אחרת מהשיוך הקיים, אחרת סטטוס ברירת המחדל.
alter table __S__.harpatka_notes
  add column if not exists meeting_short text,
  add column if not exists status_label text,
  add column if not exists status_color text;

-- השם של מי שביצע, כפי שהוא מוצג: השם בהגדרות, השם הקבוע, ו"מערכת" למי שאינו מנהל
create or replace function __S__.harpatka_note_author(p_email text, p_name text) returns text
language sql stable security definer set search_path = __S__, public as $f$
  select coalesce(
    (select nullif(trim(a.sender_name), '') from __S__.harpatka_admin_prefs a where lower(a.email) = lower(p_email)),
    case lower(p_email) when 'ofir.aviram@gmail.com' then 'אופיר' when 'hadarluri135@gmail.com' then 'הדר' end,
    case when coalesce(p_email, '') <> '' then 'מערכת' end, nullif(trim(p_name), ''), 'מערכת')
$f$;
revoke all on function __S__.harpatka_note_author(text, text) from public, anon, authenticated;

create or replace function __S__.harpatka_note_freeze() returns trigger
language plpgsql security definer set search_path = __S__, public as $f$
declare lb text; cl text;
begin
  new.author_name := __S__.harpatka_note_author(new.author_email, new.author_name);
  if new.system then
    new.meeting_short := coalesce(new.meeting_short, substring(new.body from 'מפגש\s+(?:יום\s+\S+\s+)?(\d{1,2}\.\d{1,2})'),
      case when new.meeting_id is not null then __S__.harpatka_meeting_short(new.meeting_id) end);
    if new.new_status is not null then
      select t.label, t.color into lb, cl from __S__.harpatka_statuses t where t.key = new.new_status limit 1;
      new.status_label := coalesce(new.status_label, lb, __S__.harpatka_status_label(new.new_status));
      new.status_color := coalesce(new.status_color, cl);
    end if;
  end if;
  return new;
exception when others then return new;   -- תקלה כאן לא עוצרת הערה
end $f$;
revoke all on function __S__.harpatka_note_freeze() from public, anon, authenticated;
drop trigger if exists harpatka_note_freeze on __S__.harpatka_notes;
create trigger harpatka_note_freeze before insert on __S__.harpatka_notes for each row execute function __S__.harpatka_note_freeze();

-- הערת השיוך שומרת את הסטטוס שבו נוצר השיוך
do $do$
declare d text; a text := $x$'meeting_linked', new.meeting_id);$x$;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_att_notes';
  if d is null then raise exception 'harpatka_att_notes not found'; end if;
  if position(a in d) > 0 then
    execute replace(d, a, $x$'meeting_linked', new.meeting_id, null, coalesce(new.status_key, __S__.harpatka_pay_code(new.paid, new.exempt, new.pay_requested_at, new.will_pay, new.maybe)));$x$);
  elsif position($x$'meeting_linked', new.meeting_id, null,$x$ in d) = 0 then
    raise exception 'harpatka_att_notes: meeting_linked call not found';
  end if;
end $do$;

-- הערות שיוך קיימות
do $do$
declare n record; k text; lb text;
begin
  for n in select * from __S__.harpatka_notes where system and event_type = 'meeting_linked' and meeting_id is not null and new_status is null order by created_at loop
    k := null; lb := null;
    select coalesce(a.new_data ->> 'status_key', __S__.harpatka_pay_code((a.new_data ->> 'paid')::boolean, (a.new_data ->> 'exempt')::boolean, (a.new_data ->> 'pay_requested_at')::timestamptz, (a.new_data ->> 'will_pay')::boolean, (a.new_data ->> 'maybe')::boolean)) into k
      from __S__.harpatka_audit a
      where a.table_name = 'harpatka_attendance' and a.op = 'insert' and a.new_data ->> 'participant_id' = n.participant_id::text and a.new_data ->> 'meeting_id' = n.meeting_id::text
        and a.at between n.created_at - interval '5 seconds' and n.created_at + interval '5 seconds'
      order by abs(extract(epoch from a.at - n.created_at)) limit 1;
    if k is null then
      select x.old_status, substring(x.body from '\(היה:\s*(.+)\)\s*$') into k, lb
        from __S__.harpatka_notes x
        where x.participant_id = n.participant_id and x.meeting_id = n.meeting_id and x.event_type = 'status_changed' and x.created_at > n.created_at
          and not exists (select 1 from __S__.harpatka_notes y where y.participant_id = n.participant_id and y.meeting_id = n.meeting_id and y.event_type in ('meeting_removed', 'meeting_linked') and y.created_at > n.created_at and y.created_at < x.created_at)
        order by x.created_at limit 1;
    end if;
    if k is null and not exists (select 1 from __S__.harpatka_notes y where y.participant_id = n.participant_id and y.meeting_id = n.meeting_id and y.event_type = 'meeting_removed' and y.created_at > n.created_at) then
      select coalesce(t.status_key, __S__.harpatka_pay_code(t.paid, t.exempt, t.pay_requested_at, t.will_pay, t.maybe)) into k
        from __S__.harpatka_attendance t where t.participant_id = n.participant_id and t.meeting_id = n.meeting_id;
    end if;
    update __S__.harpatka_notes set new_status = coalesce(k, 'unpaid'), status_label = coalesce(lb, __S__.harpatka_status_label(coalesce(k, 'unpaid')), coalesce(k, 'unpaid')) where id = n.id;
  end loop;
end $do$;

-- שינוי סטטוס ישן בלי מפתח: לפי השם שכתוב בהערה
update __S__.harpatka_notes n set new_status = case substring(n.body from ':\s*([^(₪]+?)\s*(?:₪|\(היה:)')
    when 'שילם' then 'paid' when 'ישלם' then 'willpay' when 'ספונטני' then 'maybe' when 'אולי' then 'maybe' when 'בטיפול' then 'requested' when 'חינם' then 'exempt' when 'חדש' then 'unpaid' when 'טרם טופל' then 'unpaid' when 'משויך' then 'unpaid' end
  where n.system and n.event_type = 'status_changed' and n.new_status is null;

-- הערות קיימות: התאריך, השם והצבע של הסטטוס, ומי שביצע
update __S__.harpatka_notes n set meeting_short = coalesce(substring(n.body from 'מפגש\s+(?:יום\s+\S+\s+)?(\d{1,2}\.\d{1,2})'), case when n.meeting_id is not null then __S__.harpatka_meeting_short(n.meeting_id) end)
  where n.system and n.meeting_short is null;
update __S__.harpatka_notes n set status_label = coalesce(n.status_label, t.label), status_color = coalesce(n.status_color, t.color)
  from __S__.harpatka_statuses t where t.key = n.new_status and (n.status_label is null or n.status_color is null);
-- שינוי סטטוס: השם כפי שכתוב בהערה
update __S__.harpatka_notes n set status_label = substring(n.body from ':\s*([^(₪]+?)\s*(?:₪|\(היה:)')
  where n.system and n.event_type in ('status_changed', 'meeting_status_changed', 'during_status_changed', 'after_status_changed')
    and substring(n.body from ':\s*([^(₪]+?)\s*(?:₪|\(היה:)') is not null
    and n.status_label is distinct from substring(n.body from ':\s*([^(₪]+?)\s*(?:₪|\(היה:)');
update __S__.harpatka_notes n set author_name = __S__.harpatka_note_author(n.author_email, n.author_name)
  where n.author_name is distinct from __S__.harpatka_note_author(n.author_email, n.author_name);
notify pgrst, 'reload schema';
