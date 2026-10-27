-- ==========================================================================
-- יומן ביקורת (audit) לכל שינוי מידע במערכת: כל הוספה, עדכון ומחיקה בכל טבלאות harpatka_*.
-- טריגר גנרי אחד רושם: מתי, איזו טבלה ושורה, סוג הפעולה, מי ביצע (חשבון גוגל; ריק = המערכת/האתר),
-- ובעדכון רק השדות ששונו (ערך ישן וחדש); בהוספה השורה החדשה, במחיקה השורה שנמחקה.
-- היומן לקריאה בלבד למנהלים (אין עדכון ומחיקה). מוחרגים: היומן עצמו, יומן הכספים (כבר יומן), לבבות אנונימיים (רעש).
-- ערכים רגישים לא נשמרים: עמודת image (צילומי מסך, נשמר רק has_image) וערכי harpatka_settings (מפתחות).
-- להריץ פעם אחת (אידמפוטנטי). הסכמה בשורה הבאה: 'public' (לבדיקות מחליפים ל-'test').
-- ==========================================================================
do $audit$
declare
  sch text := 'public';
  t text;
begin
  execute format($f$
    create table if not exists %1$I.harpatka_audit (
      id          bigint generated always as identity primary key,
      at          timestamptz not null default now(),
      table_name  text not null,
      row_key     text,
      op          text not null check (op in ('insert', 'update', 'delete')),
      actor_uid   uuid,
      actor_email text,
      old_data    jsonb,
      new_data    jsonb
    )$f$, sch);
  execute format('create index if not exists harpatka_audit_at_idx on %I.harpatka_audit (at desc)', sch);
  execute format('create index if not exists harpatka_audit_row_idx on %I.harpatka_audit (table_name, row_key, at desc)', sch);
  execute format('alter table %I.harpatka_audit enable row level security', sch);
  execute format('drop policy if exists "harpatka audit read" on %I.harpatka_audit', sch);
  execute format('create policy "harpatka audit read" on %I.harpatka_audit for select to authenticated using (public.harpatka_is_admin())', sch);
  execute format('revoke all on %I.harpatka_audit from anon, authenticated', sch);
  execute format('grant select on %I.harpatka_audit to authenticated', sch);

  execute format($f$
    create or replace function %1$I.harpatka_audit_fn() returns trigger
    language plpgsql security definer set search_path = %1$I, public as $fn$
    declare o jsonb; n jsonb; k text; od jsonb := '{}'::jsonb; nd jsonb := '{}'::jsonb; j jsonb; rk text;
    begin
      if tg_op in ('UPDATE', 'DELETE') then o := to_jsonb(old); end if;
      if tg_op in ('INSERT', 'UPDATE') then n := to_jsonb(new); end if;
      -- ערכים רגישים: צילומי מסך לא נשמרים (רק האם יש), ומפתחות ההגדרות לא נשמרים
      if tg_table_name = 'harpatka_notes' then
        if o ? 'image' then o := (o - 'image') || jsonb_build_object('has_image', (o->>'image') is not null); end if;
        if n ? 'image' then n := (n - 'image') || jsonb_build_object('has_image', (n->>'image') is not null); end if;
      elsif tg_table_name = 'harpatka_settings' then
        if o ? 'value' then o := o || jsonb_build_object('value', '***'); end if;
        if n ? 'value' then n := n || jsonb_build_object('value', '***'); end if;
      end if;
      j := coalesce(n, o);
      rk := coalesce(j->>'id', j->>'user_id', case when j ? 'participant_id' and j ? 'meeting_id' then (j->>'participant_id') || '/' || (j->>'meeting_id') end, j->>'key', j->>'days', j->>'email', j->>'code');
      if tg_op = 'UPDATE' then
        for k in select jsonb_object_keys(n) loop
          if (o->k) is distinct from (n->k) then od := od || jsonb_build_object(k, o->k); nd := nd || jsonb_build_object(k, n->k); end if;
        end loop;
        if nd = '{}'::jsonb then return null; end if;   -- עדכון בלי שינוי בפועל לא נרשם
        o := od; n := nd;
      end if;
      insert into %1$I.harpatka_audit (table_name, row_key, op, actor_uid, actor_email, old_data, new_data)
      values (tg_table_name, rk, lower(tg_op), auth.uid(), lower(nullif(auth.jwt() ->> 'email', '')), o, n);
      return null;
    end $fn$$f$, sch);
  execute format('revoke all on function %I.harpatka_audit_fn() from public, anon, authenticated', sch);

  for t in select table_name from information_schema.tables
           where table_schema = sch and table_type = 'BASE TABLE' and table_name like 'harpatka\_%'
             and table_name not in ('harpatka_audit', 'harpatka_finance_log', 'harpatka_anon_likes') loop
    execute format('drop trigger if exists harpatka_audit_trg on %I.%I', sch, t);
    execute format('create trigger harpatka_audit_trg after insert or update or delete on %I.%I for each row execute function %I.harpatka_audit_fn()', sch, t, sch);
  end loop;
end $audit$;
