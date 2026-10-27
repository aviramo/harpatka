-- מי שילם לדרך ההגעה (27.10.26): by_email בתשלומי דרכי הגעה, כדי שהתשלום ייכנס להתחשבנות בין מנהלים. התשלומים הקיימים סומנו כאופיר (לפי בעל האתר).
alter table public.harpatka_promoter_payments add column if not exists by_email text;
update public.harpatka_promoter_payments set by_email = 'ofir.aviram@gmail.com' where by_email is null;
notify pgrst, 'reload schema';
