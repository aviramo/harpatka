-- צ'אט הבוט (דף chat/): שמירת שיחות, כדי ללמוד אילו חששות חוזרים ולשפר את ההנחיות (supabase/functions/harpatka-chat/prompt.ts).
-- בפרויקט ה-Supabase של floa, בסכמה הנפרדת harpatka_wa (כמו admin/wa-floa.sql). לא נוגע ב-roster.
-- כותבת רק פונקציית השרת (service_role) דרך harpatka_chat_log. קריאה: הבעלים בלבד (harpatka_wa_chk), דרך harpatka_chat_logs_list.
-- הרצה: supabase db query --linked --project-ref aexmnaxvahblveejsbup -f admin/chat.sql   (אידמפוטנטי; להריץ אחרי admin/wa-floa.sql)
create schema if not exists harpatka_wa;
create table if not exists harpatka_wa.chat_logs (
  id uuid primary key,
  source text,                       -- מקור התנועה (למשל p = ממומן)
  ad text,                           -- מזהה המודעה (?c= בדף הצ'אט)
  messages jsonb not null default '[]'::jsonb,   -- [{ "role": "user" | "assistant", "content": "..." }]
  turns int not null default 0,      -- מספר הודעות המשתמש
  cta text,                          -- הכפתור האחרון שהבוט הציע (register, whatsapp, updates)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists chat_logs_updated_idx on harpatka_wa.chat_logs (updated_at desc);
alter table harpatka_wa.chat_logs enable row level security;
revoke all on harpatka_wa.chat_logs from public, anon, authenticated;

create or replace function public.harpatka_chat_log(p_id uuid, p_source text, p_ad text, p_messages jsonb, p_cta text) returns void
language sql security definer set search_path = public, harpatka_wa as $$
  insert into harpatka_wa.chat_logs(id, source, ad, messages, turns, cta)
  values (p_id, p_source, p_ad, coalesce(p_messages, '[]'::jsonb),
          (select count(*) from jsonb_array_elements(coalesce(p_messages, '[]'::jsonb)) e where e ->> 'role' = 'user'), p_cta)
  on conflict (id) do update set messages = excluded.messages, turns = excluded.turns, cta = coalesce(excluded.cta, harpatka_wa.chat_logs.cta), updated_at = now() $$;

create or replace function public.harpatka_chat_logs_list(p_limit int default 200) returns setof harpatka_wa.chat_logs
language plpgsql stable security definer set search_path = public, harpatka_wa as $$
begin
  perform public.harpatka_wa_chk();
  return query select * from harpatka_wa.chat_logs order by updated_at desc limit greatest(1, least(coalesce(p_limit, 200), 1000));
end $$;

revoke all on function public.harpatka_chat_log(uuid, text, text, jsonb, text), public.harpatka_chat_logs_list(int) from public, anon, authenticated;
grant execute on function public.harpatka_chat_log(uuid, text, text, jsonb, text) to service_role;
grant execute on function public.harpatka_chat_logs_list(int) to authenticated;
notify pgrst, 'reload schema';
