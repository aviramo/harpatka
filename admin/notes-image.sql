-- הערה יכולה להיות טקסט או צילום מסך (תמונה דחוסה ב-image כ-data URL), אחד מהשניים.
-- להריץ פעם אחת (אפשר להריץ שוב בלי נזק).
alter table public.harpatka_notes add column if not exists image text;
alter table public.harpatka_notes alter column body set default '';
alter table public.harpatka_notes add column if not exists has_image boolean generated always as (image is not null) stored;
do $$ begin
  alter table public.harpatka_notes add constraint harpatka_notes_content check (coalesce(btrim(body), '') <> '' or image is not null);
exception when duplicate_object then null;
end $$;
notify pgrst, 'reload schema';
