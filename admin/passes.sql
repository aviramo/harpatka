-- כרטיסיות (11.11.26): הגדרה בסוג מפגש ([{n, price}]), ומפגשים נותרים ביתרה של המשתתף (מההפקדות עם pkg_n, פחות הקצאות מכרטיסייה)
alter table __S__.harpatka_meeting_types add column if not exists passes jsonb not null default '[]'::jsonb;
alter table __S__.harpatka_payments add column if not exists pass_type_id uuid;
do $do$
declare d text;
begin
  d := pg_get_functiondef('__S__.harpatka_me(uuid)'::regprocedure);
  if position('''sessions''' in d) = 0 then
    d := replace(d, '''balance'', bal,', '''balance'', bal, ''sessions'', (select coalesce(sum(case when p.kind = ''deposit'' and coalesce(p.pkg_n, 0) > 0 then p.pkg_n when p.pkg and p.kind = ''payment'' then -1 when p.pkg and p.kind = ''credit'' then 1 else 0 end), 0) from __S__.harpatka_payments p where p.participant_id = pid), ');
    execute d;
  end if;
end $do$;
-- "שולם ₪80" באזור האישי מציין גם באיזו דרך שולם: harpatka_me מחזירה paid_via לכל מפגש (למשל "₪30 מהקרדיט · ₪50 בפייבוקס" או "בפייבוקס")
do $do$
declare d text;
begin
  d := pg_get_functiondef('__S__.harpatka_me(uuid)'::regprocedure);
  if position('''paid_via''' in d) = 0 then
    d := replace(d, '''paid'', coalesce(', '''paid_via'', (select string_agg(t.lab, '' · '' order by t.lab) from (select case when p.pkg then ''מהכרטיסייה'' when coalesce(p.from_credit, false) then ''מהקרדיט'' else coalesce((select pm.name from __S__.harpatka_pay_methods pm where pm.key = p.method limit 1), nullif(p.method, ''''), ''אחר'') end as lab, sum(p.amount) as amt from __S__.harpatka_payments p where p.participant_id = pid and p.meeting_id = mt.id and p.kind = ''payment'' group by 1 having sum(p.amount) > 0) t0, lateral (select case when t0.lab in (''מהקרדיט'', ''מהכרטיסייה'') then t0.lab else ''ב'' || t0.lab end as lab) t),' || chr(10) || '      ''paid'', coalesce(');
    execute d;
  end if;
end $do$;
