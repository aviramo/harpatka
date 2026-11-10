-- איש קשר אופציונלי לשיווק ממומן (שם מלא וטלפון). תוספת בלבד, אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/promoter-contact.sql | supabase db query --linked
alter table __S__.harpatka_promoters add column if not exists contact_name text;
alter table __S__.harpatka_promoters add column if not exists contact_phone text;
