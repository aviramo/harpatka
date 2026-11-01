-- אזור אישי: אפשר לשלם (ולדווח על תשלום) גם על מפגשים שהסתיימו (1.11.26).
-- 1) harpatka_me מחזירה מחיר גם למפגש שעבר (מחיר ביום המפגש: המדרגה האחרונה), כדי שכפתור התשלום יציג סכום.
-- 2) harpatka_report_payment_core כבר לא דוחה דיווח על מפגש שעבר ('past' רק כשהמפגש לא קיים); הסכום שמדווח הוא מחיר ביום המפגש.
-- הרשמה וביטול רישום למפגש שעבר נשארים חסומים (harpatka_me_register / harpatka_me_unregister לא שונו).
-- אידמפוטנטי. להחליף __S__ ב-test או ב-public:  sed 's/__S__/test/g' admin/me-pay-past.sql | supabase db query --linked
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_me';
  if d is null then raise exception 'harpatka_me not found'; end if;
  if d like '%greatest(mt.meeting_date - today, 0)%' then null;   -- כבר הוחל
  else
    d := replace(d, 'case when mt.meeting_date >= today then __S__.harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today) end', '__S__.harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0))');
    if d not like '%greatest(mt.meeting_date - today, 0)%' then raise exception 'harpatka_me patch did not apply'; end if;
    execute d;
  end if;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = 'harpatka_report_payment_core';
  if d is null then raise exception 'harpatka_report_payment_core not found'; end if;
  if d like '%if not found then return ''past''; end if;%' then null;   -- כבר הוחל
  else
    d := replace(d, 'if not found or mt.meeting_date < today then return ''past''; end if;', 'if not found then return ''past''; end if;');
    d := replace(d, 'harpatka_meeting_price(mt.price_tiers, mt.meeting_date - today)', 'harpatka_meeting_price(mt.price_tiers, greatest(mt.meeting_date - today, 0))');
    if d not like '%if not found then return ''past''; end if;%' or d not like '%greatest(mt.meeting_date - today, 0)%' then raise exception 'core patch did not apply'; end if;
    execute d;
  end if;
end $$;
notify pgrst, 'reload schema';
