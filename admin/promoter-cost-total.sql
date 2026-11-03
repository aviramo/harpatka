-- סוג עלות שלישי לדרך הגעה (3.11.26): "עלות כללית". בלי עלות לליד ובלי יתרה: הסכום נרשם בהתחשבנות (כמה ששילמנו), והעלות לליד נגזרת ממנו לתקופה שמאז ההתחשבנות הקודמת.
-- תוספת בלבד. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/promoter-cost-total.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/promoter-cost-total.sql | supabase db query --linked
alter table __S__.harpatka_promoters add column if not exists cost_total boolean not null default false;
