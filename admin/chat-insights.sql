-- צ'אט הבוט: סטטיסטיקת פתיחות, כדי שהבוט ילמד מה עבד ומה לא כשהוא כותב את הודעת הפתיחה הבאה.
-- לכל פתיחה: כמה אנשים ראו אותה, כמה ענו, כמה שיחות עמוקות (3 הודעות ומעלה), אורך התגובה הראשונה, וכמה הגיעו להצעה.
-- נספרות רק שיחות ישנות מ-10 דקות (שיהיה זמן לענות). בלי טקסט של משתמשים, רק מספרים.
-- הרצה: supabase db query --linked --project-ref aexmnaxvahblveejsbup -f admin/chat-insights.sql   (אידמפוטנטי; אחרי admin/chat.sql)
create or replace function public.harpatka_chat_opening_stats(p_ad text, p_limit int default 10) returns jsonb
language sql stable security definer set search_path = public, harpatka as $$
  with r as (
    select turns, cta, created_at,
      (select string_agg(a.m ->> 'content', E'\n' order by a.o)
         from jsonb_array_elements(messages) with ordinality as a(m, o)
        where a.m ->> 'role' = 'assistant'
          and a.o < coalesce((select min(u.o) from jsonb_array_elements(messages) with ordinality as u(m, o) where u.m ->> 'role' = 'user'), 99)) as opening,
      (select length(u.m ->> 'content') from jsonb_array_elements(messages) with ordinality as u(m, o) where u.m ->> 'role' = 'user' order by u.o limit 1) as first_len
    from harpatka.chat_logs
    where ad = p_ad and created_at < now() - interval '10 minutes'
    order by created_at desc limit 400
  ), g as (
    select opening,
      count(*) as n,
      count(*) filter (where turns >= 1) as replied,
      count(*) filter (where turns >= 3) as deep,
      count(*) filter (where cta is not null) as offered,
      coalesce(round(avg(first_len) filter (where turns >= 1))::int, 0) as avg_first_len,
      max(created_at) as last_at
    from r where opening is not null group by opening
  )
  select coalesce(jsonb_agg(to_jsonb(g) order by g.last_at desc), '[]'::jsonb) from (select * from g order by last_at desc limit greatest(1, least(coalesce(p_limit, 10), 30))) g
$$;
revoke all on function public.harpatka_chat_opening_stats(text, int) from public, anon, authenticated;
grant execute on function public.harpatka_chat_opening_stats(text, int) to service_role;
notify pgrst, 'reload schema';

-- למידה משאלות לאורך השיחה: השאלות של הבוט שאחריהן האדם נעלם, והשאלות שעוררו תשובה ארוכה (60 תווים ומעלה).
-- רק הטקסט של הבוט, לעולם לא של האדם. נספרות שיחות ישנות מ-30 דקות. p_ad ריק = כל המודעות (יותר נתונים).
create or replace function public.harpatka_chat_question_stats(p_ad text default null) returns jsonb
language sql stable security definer set search_path = public, harpatka as $$
  with r as (
    select id, messages, created_at from harpatka.chat_logs
    where (p_ad is null or ad = p_ad) and created_at < now() - interval '30 minutes' and turns >= 1
    order by created_at desc limit 300
  ), m as (
    select r.id, r.created_at, a.m ->> 'role' as role, a.m ->> 'content' as content, a.o, max(a.o) over (partition by r.id) as last_o
    from r, jsonb_array_elements(r.messages) with ordinality as a(m, o)
  ), dropped as (
    select content, created_at from m where role = 'assistant' and o = last_o and content like '%?%' order by created_at desc limit 8
  ), drew as (
    select m.content, m.created_at from m join m n on n.id = m.id and n.o = m.o + 1 and n.role = 'user'
    where m.role = 'assistant' and m.content like '%?%' and length(n.content) >= 60 order by m.created_at desc limit 8
  )
  select jsonb_build_object(
    'dropped', coalesce((select jsonb_agg(left(content, 200)) from dropped), '[]'::jsonb),
    'drew', coalesce((select jsonb_agg(left(content, 200)) from drew), '[]'::jsonb))
$$;
revoke all on function public.harpatka_chat_question_stats(text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_question_stats(text) to service_role;
notify pgrst, 'reload schema';
