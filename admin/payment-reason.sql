-- סיבת רישום לתשלום/הפקדה (למשל alloc_removed: כסף שחזר ליתרה במחיקת הקצאה). אידמפוטנטי; להריץ על public ועל test
alter table public.harpatka_payments add column if not exists reason text;
alter table test.harpatka_payments add column if not exists reason text;
