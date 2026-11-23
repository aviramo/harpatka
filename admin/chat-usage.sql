-- הגנה מפני ניצול לרעה של הצ'אט (פרויקט ה-Supabase של floa, סכמה harpatka). תוספת בלבד, בטוחה להרצה חוזרת.
-- כל קריאה לצ'אט נרשמת עם מזהה אקראי של המכשיר (נוצר בדפדפן, לא טביעת אצבע) ועם גיבוב של כתובת הרשת (לא הכתובת עצמה),
-- והפונקציה מחזירה כמה קריאות היו ב-24 השעות האחרונות, כדי שהשרת יחליט אם להמשיך לקרוא למודל.
create table if not exists harpatka.chat_usage (
  id bigserial primary key,
  at timestamptz not null default now(),
  device text,
  ip_hash text,
  mode text
);
create index if not exists chat_usage_device_at on harpatka.chat_usage (device, at desc);
create index if not exists chat_usage_ip_at on harpatka.chat_usage (ip_hash, at desc);
create index if not exists chat_usage_at on harpatka.chat_usage (at desc);
alter table harpatka.chat_usage enable row level security;   -- בלי מדיניות: רק service_role

create or replace function public.harpatka_chat_usage_hit(p_device text, p_ip text, p_mode text)
returns jsonb language plpgsql security definer set search_path = harpatka, public as $$
declare d int; i int; t int;
begin
  insert into harpatka.chat_usage(device, ip_hash, mode) values (left(p_device, 64), left(p_ip, 64), left(p_mode, 12));
  if random() < 0.01 then delete from harpatka.chat_usage where at < now() - interval '14 days'; end if;
  select count(*) into d from harpatka.chat_usage where device = left(p_device, 64) and p_device is not null and p_device <> '' and at > now() - interval '24 hours';
  select count(*) into i from harpatka.chat_usage where ip_hash = left(p_ip, 64) and p_ip is not null and p_ip <> '' and at > now() - interval '24 hours';
  select count(*) into t from harpatka.chat_usage where at > now() - interval '24 hours';
  return jsonb_build_object('device', d, 'ip', i, 'total', t);
end $$;
revoke all on function public.harpatka_chat_usage_hit(text, text, text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_usage_hit(text, text, text) to service_role;
