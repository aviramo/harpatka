-- האתר הציבורי קורא את ברירות המחדל של סוג המפגש (31.10.26): עמוד הבית ופופאפ ההרשמה מציגים לכל שדה את הערך של המפגש,
-- ואם הוא ריק את הערך של סוג המפגש שלו (במקום שם ותמונת ברירת המחדל הגלובליים של harpatka_public_settings).
-- קריאה בלבד, רק שדות התצוגה (בלי הודעת פרטי המפגש ובלי הגדרות הגעה). אידמפוטנטי.
-- בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_. בקידום: אחרי meeting-types.sql.

grant select (id, name, sort, meeting_time, city, max_participants, directions, price_tiers, image_url, created_at)
  on public.harpatka_meeting_types to anon;
drop policy if exists "harpatka public read types" on public.harpatka_meeting_types;
create policy "harpatka public read types" on public.harpatka_meeting_types for select to anon using (true);

notify pgrst, 'reload schema';
