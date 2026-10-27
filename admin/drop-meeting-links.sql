-- הסרת קישורי הניווט מהמפגש (בוטלו לבקשת בעל האתר). להריץ אחרי פרסום הקוד.
alter table public.harpatka_meetings drop column if exists maps_url, drop column if exists waze_url;
alter table test.harpatka_meetings drop column if exists maps_url, drop column if exists waze_url;
