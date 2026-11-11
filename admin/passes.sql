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
-- קרדיט כספי לא כולל כרטיסייה: הפקדה עם pkg_n והקצאה מכרטיסייה (pkg) לא נכנסות לסכום (המפגשים נספרים בנפרד ב-sessions)
do $do$
declare d text; f text;
begin
  foreach f in array array['harpatka_me(uuid)', 'harpatka_me_pay_credit(uuid,uuid)'] loop
    begin
      d := pg_get_functiondef(('__S__.' || f)::regprocedure);
      if position('into bal from __S__.harpatka_payments where participant_id = pid;' in d) > 0 then
        d := replace(d, 'into bal from __S__.harpatka_payments where participant_id = pid;', 'into bal from __S__.harpatka_payments where participant_id = pid and not coalesce(pkg, false) and not (kind = ''deposit'' and coalesce(pkg_n, 0) > 0);');
        execute d;
      end if;
    exception when undefined_function then null; end;
  end loop;
end $do$;
-- רכישת כרטיסייה מהאזור האישי: בקשה שנרשמת (והערת מערכת), והמנהל מזין את התשלום ב"קבלת תשלום" עם הכרטיסייה
create table if not exists __S__.harpatka_pass_requests (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references __S__.harpatka_participants(id) on delete cascade,
  type_id uuid, n int not null, price numeric not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);
alter table __S__.harpatka_pass_requests enable row level security;
drop policy if exists "harpatka admin pass requests" on __S__.harpatka_pass_requests;
create policy "harpatka admin pass requests" on __S__.harpatka_pass_requests for all to authenticated using (__S__.__ADM__()) with check (__S__.__ADM__());
create or replace function __S__.harpatka_me_buy_pass(p_type uuid, p_n int, p_as uuid default null)
returns text language plpgsql security definer set search_path = __S__, public as $$
declare m __S__.harpatka_members; pid uuid; t __S__.harpatka_meeting_types; pr numeric;
begin
  if p_as is not null then raise exception 'view_only'; end if;
  select * into m from __S__.harpatka_members where user_id = auth.uid();
  if not found or m.status <> 'approved' or m.participant_id is null then raise exception 'forbidden'; end if;
  pid := m.participant_id;
  select * into t from __S__.harpatka_meeting_types where id = p_type;
  if not found then return 'not_found'; end if;
  select (x->>'price')::numeric into pr from jsonb_array_elements(coalesce(t.passes, '[]'::jsonb)) x where (x->>'n')::int = p_n limit 1;
  if pr is null then return 'not_found'; end if;
  if exists (select 1 from __S__.harpatka_pass_requests where participant_id = pid and type_id = p_type and n = p_n and status = 'pending' and created_at > now() - interval '1 day') then return 'exists'; end if;
  insert into __S__.harpatka_pass_requests (participant_id, type_id, n, price) values (pid, p_type, p_n, pr);
  begin perform __S__.harpatka_sys_note(pid, 'ביקש/ה לרכוש כרטיסייה ' || p_n || ' מפגשים ב-₪' || trim(to_char(pr, 'FM999990.##')) || ' דרך האזור האישי', 'pass_requested'); exception when others then null; end;
  return 'ok';
end $$;
revoke all on function __S__.harpatka_me_buy_pass(uuid, int, uuid) from public;
grant execute on function __S__.harpatka_me_buy_pass(uuid, int, uuid) to authenticated;
-- harpatka_me מחזירה passes: הכרטיסיות שהוגדרו בסוגי המפגש
do $do$
declare d text;
begin
  d := pg_get_functiondef('__S__.harpatka_me(uuid)'::regprocedure);
  if position('''passes''' in d) = 0 then
    d := replace(d, '''balance'', bal,', '''balance'', bal, ''passes'', (select coalesce(jsonb_agg(jsonb_build_object(''type_id'', mt.id, ''type_name'', mt.name, ''n'', (x->>''n'')::int, ''price'', (x->>''price'')::numeric) order by mt.sort, (x->>''n'')::int), ''[]''::jsonb) from __S__.harpatka_meeting_types mt, jsonb_array_elements(coalesce(mt.passes, ''[]''::jsonb)) x where jsonb_typeof(mt.passes) = ''array''), ');
    execute d;
  end if;
end $do$;
