-- שם ברירת מחדל למפגש (הגדרה אחת לכל המערכת, גלויה לציבור): מוצע ביצירת מפגש חדש, ומוצג בעמוד הבית למפגש שאין לו שם.
-- טבלת הגדרות ציבוריות קטנה (מפתח וערך): קריאה לכולם, כתיבה למנהלים. אידמפוטנטי; להריץ על public ועל test.
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_admin_prefs drop column if exists meeting_name_default', s);
    execute format('create table if not exists %I.harpatka_public_settings (key text primary key, value text, updated_at timestamptz not null default now())', s);
    execute format('alter table %I.harpatka_public_settings enable row level security', s);
    execute format('drop policy if exists "harpatka admin all" on %I.harpatka_public_settings', s);
    execute format('create policy "harpatka admin all" on %I.harpatka_public_settings for all to authenticated using (public.harpatka_is_admin()) with check (public.harpatka_is_admin())', s);
    execute format('drop policy if exists "harpatka public read" on %I.harpatka_public_settings', s);
    execute format('create policy "harpatka public read" on %I.harpatka_public_settings for select to anon, authenticated using (true)', s);
    execute format('grant select on %I.harpatka_public_settings to anon', s);
    execute format('grant select, insert, update, delete on %I.harpatka_public_settings to authenticated', s);
  end loop;
end $$;
