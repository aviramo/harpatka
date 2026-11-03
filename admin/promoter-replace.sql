-- מחיקת דרך הגעה והעברת כל מה שמקושר אליה לדרך הגעה אחרת, בטרנזקציה אחת (3.11.26).
-- משתתפים (גם לפי הקוד בקישור), שיוכים למפגשים, תשלומים ותשלומים לדרך ההגעה עוברים ל-p_to, ואז היא נמחקת.
-- בלי p_to: נמחקת רק כשאין לה שום קישור (אחרת מוחזר has_links ולא קורה כלום).
-- רץ בהרשאות המשתמש, ולכן ה-RLS של הטבלאות (מנהלים בלבד) חל עליו. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/promoter-replace.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/promoter-replace.sql | supabase db query --linked
create or replace function __S__.harpatka_promoter_replace(p_from uuid, p_to uuid default null)
returns text language plpgsql set search_path = __S__, public as $$
declare f __S__.harpatka_promoters; t __S__.harpatka_promoters;
begin
  select * into f from __S__.harpatka_promoters where id = p_from;
  if not found then return 'not_found'; end if;
  if p_to is null then
    if exists (select 1 from __S__.harpatka_participants where promoter_id = p_from or (f.code is not null and source_code = f.code) or (f.code = 'p' and source = 'site-ad' and source_code is null and promoter_id is null))
      or exists (select 1 from __S__.harpatka_attendance where promoter_id = p_from or source_promoter_id = p_from)
      or exists (select 1 from __S__.harpatka_payments where promoter_id = p_from)
      or exists (select 1 from __S__.harpatka_promoter_payments where promoter_id = p_from) then
      return 'has_links';
    end if;
  else
    if p_to = p_from then return 'same'; end if;
    select * into t from __S__.harpatka_promoters where id = p_to;
    if not found then return 'no_target'; end if;
    update __S__.harpatka_participants
      set promoter_id = p_to, source_code = case when source_code = f.code then t.code else source_code end
      where promoter_id = p_from or (f.code is not null and source_code = f.code) or (f.code = 'p' and source = 'site-ad' and source_code is null and promoter_id is null);
    update __S__.harpatka_attendance set promoter_id = p_to where promoter_id = p_from;
    update __S__.harpatka_attendance set source_promoter_id = p_to where source_promoter_id = p_from;
    update __S__.harpatka_payments set promoter_id = p_to where promoter_id = p_from;
    update __S__.harpatka_promoter_payments set promoter_id = p_to where promoter_id = p_from;
  end if;
  delete from __S__.harpatka_promoters where id = p_from;
  return 'ok';
end $$;
revoke all on function __S__.harpatka_promoter_replace(uuid, uuid) from public, anon;
grant execute on function __S__.harpatka_promoter_replace(uuid, uuid) to authenticated;
