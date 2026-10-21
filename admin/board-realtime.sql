-- לוח השיתופים בזמן אמת: כל שינוי בפוסטים, בתגובות, בלבבות ובחיבורים שולח אות ריק בערוץ ציבורי "board" (בלי נתונים),
-- והדפדפנים שמחוברים לערוץ טוענים מחדש את הלוח דרך הפונקציה harpatka_board_feed (שמחילה את כללי הצפייה).
create or replace function public.harpatka_board_signal()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform realtime.send('{}'::jsonb, 'change', 'board', false);
  return null;
exception when others then return null;
end $$;
revoke all on function public.harpatka_board_signal() from public, anon, authenticated;

drop trigger if exists harpatka_board_signal on public.harpatka_posts;
create trigger harpatka_board_signal after insert or update or delete on public.harpatka_posts for each statement execute function public.harpatka_board_signal();
drop trigger if exists harpatka_board_signal on public.harpatka_likes;
create trigger harpatka_board_signal after insert or delete on public.harpatka_likes for each statement execute function public.harpatka_board_signal();
drop trigger if exists harpatka_board_signal on public.harpatka_members;
create trigger harpatka_board_signal after update of status on public.harpatka_members for each statement execute function public.harpatka_board_signal();
