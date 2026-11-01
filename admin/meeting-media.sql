-- תמונה או סרטון בהוראות ההגעה של מפגש או סוג מפגש (1.11.26): דלי אחסון ציבורי meeting-media שמנהלים מעלים אליו מדף הניהול (הקישור נכנס לסוף הוראות ההגעה: "לפרטים נוספים: <קישור>").
-- הדלי הוא של כל הפרויקט (לא של סכמה): ההרצה פעם אחת מספיקה לבדיקות ולאמת. אידמפוטנטי.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meeting-media', 'meeting-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do update set public = true, file_size_limit = 52428800, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm'];

-- קריאה לכולם (דלי ציבורי, כדי שהקישור ייפתח בוואטסאפ), כתיבה ומחיקה למנהלים בלבד
drop policy if exists "harpatka meeting media read" on storage.objects;
create policy "harpatka meeting media read" on storage.objects for select to anon, authenticated using (bucket_id = 'meeting-media');
drop policy if exists "harpatka meeting media admin insert" on storage.objects;
create policy "harpatka meeting media admin insert" on storage.objects for insert to authenticated with check (bucket_id = 'meeting-media' and public.harpatka_is_admin());
drop policy if exists "harpatka meeting media admin update" on storage.objects;
create policy "harpatka meeting media admin update" on storage.objects for update to authenticated using (bucket_id = 'meeting-media' and public.harpatka_is_admin());
drop policy if exists "harpatka meeting media admin delete" on storage.objects;
create policy "harpatka meeting media admin delete" on storage.objects for delete to authenticated using (bucket_id = 'meeting-media' and public.harpatka_is_admin());
