-- ניתוק חשבון גוגל ממשתתף (1.11.26): ניתוק מסיר את הקישור למשתתף, והחשבון יכול להתחבר שוב (בטלפון). רק חסימה (blocked) חוסמת כניסה.
-- קודם "ניתוק" הוסיף סטטוס removed שנשאר משויך למשתתף, ו-harpatka_me החזירה לו "חסום" ("לא ניתן להתחבר דרך החשבון הזה").
-- 1) harpatka_me: removed כבר לא חוסם (לשורות ישנות; הן נחשבות כחשבון בלי משתתף). 2) שורות removed קיימות הופכות לחשבון בלי משתתף.
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public:  sed 's/__S__/test/g' admin/members-unlink.sql | supabase db query --linked
do $$
declare r record; d text;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me' loop
    d := pg_get_functiondef(r.oid);
    if d like '%m.status = ''blocked'' or m.status = ''removed''%' then
      d := replace(d, 'm.status = ''blocked'' or m.status = ''removed''', 'm.status = ''blocked''');
      if d like '%m.status = ''removed''%' then raise exception 'patch did not apply'; end if;
      execute d;
    end if;
  end loop;
end $$;
update __S__.harpatka_members set participant_id = null, status = 'pending' where status = 'removed';
notify pgrst, 'reload schema';
