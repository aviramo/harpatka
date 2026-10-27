-- תמונה לכל מפגש: עמודה image_url (כתובת ציבורית) ודלי אחסון ציבורי meeting-images שמנהלים מעלים אליו מדף הניהול. אידמפוטנטי; להריץ על public ועל test (הדלי משותף).
do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    execute format('alter table %I.harpatka_meetings add column if not exists image_url text', s);
  end loop;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meeting-images', 'meeting-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- קריאה לכולם (דלי ציבורי), כתיבה ומחיקה למנהלים בלבד
drop policy if exists "harpatka meeting images read" on storage.objects;
create policy "harpatka meeting images read" on storage.objects for select to anon, authenticated using (bucket_id = 'meeting-images');
drop policy if exists "harpatka meeting images admin insert" on storage.objects;
create policy "harpatka meeting images admin insert" on storage.objects for insert to authenticated with check (bucket_id = 'meeting-images' and public.harpatka_is_admin());
drop policy if exists "harpatka meeting images admin update" on storage.objects;
create policy "harpatka meeting images admin update" on storage.objects for update to authenticated using (bucket_id = 'meeting-images' and public.harpatka_is_admin());
drop policy if exists "harpatka meeting images admin delete" on storage.objects;
create policy "harpatka meeting images admin delete" on storage.objects for delete to authenticated using (bucket_id = 'meeting-images' and public.harpatka_is_admin());
