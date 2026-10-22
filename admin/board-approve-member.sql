-- אישור חיבור של משתמש (בדף הניהול) מפרסם גם את הפוסטים והתגובות שכתב עד אותו רגע וממתינים לאישור.
-- פריטים שיכתוב אחר כך ממשיכים לחכות לאישור נפרד של מנהל.
create or replace function public.harpatka_members_publish_pending()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    update public.harpatka_posts set approved_at = now() where user_id = new.user_id and approved_at is null and deleted_at is null;
  end if;
  return null;
end $$;
revoke all on function public.harpatka_members_publish_pending() from public, anon, authenticated;
drop trigger if exists harpatka_members_publish_pending on public.harpatka_members;
create trigger harpatka_members_publish_pending after update of status on public.harpatka_members for each row execute function public.harpatka_members_publish_pending();
