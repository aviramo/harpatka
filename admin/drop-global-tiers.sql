-- מחיקת ההגדרה הגלובלית של מדרגות המחיר (המדרגות עברו לכל מפגש, העמודה harpatka_meetings.price_tiers). להריץ אחרי admin/meeting-tiers.sql ופרסום הקוד.
drop table if exists public.harpatka_price_tiers;
drop table if exists test.harpatka_price_tiers;
