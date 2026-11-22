-- צ'אט הבוט (דף chat/): שמירת שיחות, כדי ללמוד אילו חששות חוזרים ולשפר את ההנחיות (supabase/functions/harpatka-chat/prompt.ts).
-- כותבת רק פונקציית השרת (service role), בלי מדיניות כתיבה לציבור. קריאה: מנהלים בלבד.
-- אידמפוטנטי. להריץ קודם על test (החלפת __S__ ב-test), ורק אחרי אישור על public (החלפת __S__ ב-public). __ADM__ = harpatka_is_admin.
-- דוגמה: sed 's/__S__/test/g; s/__ADM__/harpatka_is_admin/g' admin/chat.sql
create table if not exists __S__.harpatka_chat_logs (
  id uuid primary key,
  source text,                       -- מקור התנועה (למשל p = ממומן)
  ad text,                           -- מזהה המודעה (?c= בדף הצ'אט)
  messages jsonb not null default '[]'::jsonb,   -- [{ "role": "user" | "assistant", "content": "..." }]
  turns int not null default 0,      -- מספר הודעות המשתמש
  cta text,                          -- הכפתור האחרון שהבוט הציע (register, whatsapp, updates)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists harpatka_chat_logs_updated_idx on __S__.harpatka_chat_logs (updated_at desc);
alter table __S__.harpatka_chat_logs enable row level security;
drop policy if exists "harpatka admin read" on __S__.harpatka_chat_logs;
create policy "harpatka admin read" on __S__.harpatka_chat_logs for select to authenticated using (public.__ADM__());
revoke all on __S__.harpatka_chat_logs from anon;
grant all on __S__.harpatka_chat_logs to service_role;
