-- סימון שנשלחה למשתתף הודעת פרטי הערב (ביום המפגש), לכל שיוך משתתף-מפגש
alter table public.harpatka_attendance add column if not exists details_sent_at timestamptz;
notify pgrst, 'reload schema';
