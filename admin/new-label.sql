-- שינוי השם של הסטטוס "טרם טופל" ל"חדש" בהערות המערכת (הקוד הפנימי unpaid נשאר)
create or replace function public.harpatka_pay_status(p_paid boolean, p_exempt boolean, p_req timestamptz, p_will boolean, p_maybe boolean)
returns text language sql immutable as $$
  select case when coalesce(p_exempt, false) then 'חינם' when coalesce(p_paid, false) then 'שילם' when coalesce(p_will, false) then 'ישלם' when coalesce(p_maybe, false) then 'ספונטני' when p_req is not null then 'בטיפול' else 'חדש' end;
$$;
