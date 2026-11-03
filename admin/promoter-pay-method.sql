-- דרך תשלום בתשלום לדרך הגעה (3.11.26): פייבוקס, ביט, מזומן וכו', מפתח מתוך harpatka_pay_methods, כמו בתשלום של משתתף.
-- תוספת בלבד: תשלומים קיימים נשארים בלי דרך תשלום. אידמפוטנטי. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/promoter-pay-method.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/promoter-pay-method.sql | supabase db query --linked
alter table __S__.harpatka_promoter_payments add column if not exists method text;
