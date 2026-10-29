-- הערת מערכת כשמשתתף מחבר חשבון גוגל (29.10.26): נרשמת כשחיבור (harpatka_members) מקבל משתתף. מוצגת בדף הניהול כשני צ'יפים: האימייל של החשבון והטלפון.
-- אידמפוטנטי; להריץ על public, ואז admin/test-site.sql (הפונקציה מועתקת והטריגר נוצר שם).
create or replace function public.harpatka_member_linked_note() returns trigger
language plpgsql security definer set search_path = public as $$
declare ph text;
begin
  if new.participant_id is null then return new; end if;
  if tg_op = 'UPDATE' and old.participant_id is not distinct from new.participant_id then return new; end if;
  select coalesce(nullif(p.phone, ''), nullif(p.phone_norm, ''), '') into ph from public.harpatka_participants p where p.id = new.participant_id;
  begin
    perform public.harpatka_sys_note(new.participant_id, 'חובר חשבון גוגל ' || coalesce(nullif(new.email, ''), 'ללא מייל') || ' · ' || coalesce(ph, ''), 'google_linked');
  exception when others then null;
  end;
  return new;
end $$;
revoke all on function public.harpatka_member_linked_note() from public, anon, authenticated;
drop trigger if exists harpatka_member_linked_note on public.harpatka_members;
create trigger harpatka_member_linked_note after insert or update of participant_id on public.harpatka_members
  for each row execute function public.harpatka_member_linked_note();
