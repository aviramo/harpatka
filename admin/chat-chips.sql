-- למידה מהתשובות המוכנות של הצ'אט (פרויקט ה-Supabase של floa, סכמה harpatka). תוספת בלבד, בטוחה להרצה חוזרת.
-- לכל מודעה ולכל תשובה מוכנה: כמה פעמים הוצעה (והאדם המשיך לענות) וכמה פעמים נלחצה. רק טקסט התשובה המוכנה ומספרים, בלי מזהה אדם.
create table if not exists harpatka.chat_chips (
  ad text not null,
  chip text not null,
  shown int not null default 0,
  clicked int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (ad, chip)
);
alter table harpatka.chat_chips enable row level security;

create or replace function public.harpatka_chat_chip_event(p_ad text, p_shown text[], p_clicked text) returns void
language plpgsql security definer set search_path = public, harpatka as $$
declare c text;
begin
  p_ad := left(coalesce(p_ad, ''), 40);
  foreach c in array coalesce(p_shown, '{}'::text[]) loop
    c := left(trim(c), 60);
    if c = '' then continue; end if;
    insert into harpatka.chat_chips (ad, chip, shown, clicked) values (p_ad, c, 1, case when c = trim(coalesce(p_clicked, '')) then 1 else 0 end)
    on conflict (ad, chip) do update set shown = harpatka.chat_chips.shown + 1,
      clicked = harpatka.chat_chips.clicked + case when c = trim(coalesce(p_clicked, '')) then 1 else 0 end, updated_at = now();
  end loop;
end $$;
revoke all on function public.harpatka_chat_chip_event(text, text[], text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_chip_event(text, text[], text) to service_role;

-- תשובות שנלחצו הכי הרבה, ותשובות שהוצעו הרבה ולא נלחצו. מספרים נמוכים לא נחשבים (בלי מדגם אין מסקנה).
create or replace function public.harpatka_chat_chip_stats(p_ad text) returns jsonb
language sql stable security definer set search_path = public, harpatka as $$
  select jsonb_build_object(
    'liked', coalesce((select jsonb_agg(chip) from (select chip from harpatka.chat_chips where ad = p_ad and shown >= 2 and clicked >= 1
       order by clicked::numeric / shown desc, shown desc limit 3) x), '[]'::jsonb),
    'ignored', coalesce((select jsonb_agg(chip) from (select chip from harpatka.chat_chips where ad = p_ad and shown >= 4 and clicked = 0
       order by shown desc limit 3) y), '[]'::jsonb))
$$;
revoke all on function public.harpatka_chat_chip_stats(text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_chip_stats(text) to service_role;
notify pgrst, 'reload schema';

-- הצעות של הבוט לפי שלב (warm = לשמוע איך עושים את זה, bio = לשמוע על ביודנסה, meeting = לשמוע על מפגש, details = זמן ומקום, link = קישור)
-- ומה האדם ענה אחריהן (yes / no / other). רק טקסט ההצעה ומספרים, בלי מזהה אדם.
create table if not exists harpatka.chat_offers (
  ad text not null,
  stage text not null,
  text text not null,
  offered int not null default 0,
  yes int not null default 0,
  no int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (ad, stage, text)
);
alter table harpatka.chat_offers enable row level security;

create or replace function public.harpatka_chat_offer_event(p_ad text, p_stage text, p_text text, p_outcome text) returns void
language plpgsql security definer set search_path = public, harpatka as $$
begin
  p_ad := left(coalesce(p_ad, ''), 40); p_text := left(trim(coalesce(p_text, '')), 160);
  if p_text = '' or p_stage not in ('warm', 'bio', 'meeting', 'details', 'link') then return; end if;
  insert into harpatka.chat_offers (ad, stage, text, offered, yes, no)
  values (p_ad, p_stage, p_text, 1, (p_outcome = 'yes')::int, (p_outcome = 'no')::int)
  on conflict (ad, stage, text) do update set offered = harpatka.chat_offers.offered + 1,
    yes = harpatka.chat_offers.yes + (p_outcome = 'yes')::int, no = harpatka.chat_offers.no + (p_outcome = 'no')::int, updated_at = now();
end $$;
revoke all on function public.harpatka_chat_offer_event(text, text, text, text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_offer_event(text, text, text, text) to service_role;

-- תקציר מצומצם: לכל שלב, ההצעה הכי מצליחה וההצעה הכי פחות מצליחה (לפחות 2 הצעות), עד 5 שלבים
create or replace function public.harpatka_chat_offer_stats(p_ad text) returns jsonb
language sql stable security definer set search_path = public, harpatka as $$
  with o as (select stage, text, offered, yes, no, yes::numeric / offered as r from harpatka.chat_offers where ad = p_ad and offered >= 2),
  best as (select distinct on (stage) stage, text, yes, offered from o where yes > 0 order by stage, r desc, offered desc),
  worst as (select distinct on (stage) stage, text, no, offered from o where no > 0 and yes = 0 order by stage, no desc, offered desc)
  select jsonb_build_object(
    'best', coalesce((select jsonb_agg(jsonb_build_object('stage', stage, 'text', text, 'yes', yes, 'of', offered)) from best), '[]'::jsonb),
    'worst', coalesce((select jsonb_agg(jsonb_build_object('stage', stage, 'text', text, 'no', no, 'of', offered)) from worst), '[]'::jsonb))
$$;
revoke all on function public.harpatka_chat_offer_stats(text) from public, anon, authenticated;
grant execute on function public.harpatka_chat_offer_stats(text) to service_role;
notify pgrst, 'reload schema';
