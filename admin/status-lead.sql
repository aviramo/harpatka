-- מתי סטטוסי המפגש זמינים לבחירה, לכל סוג מפגש (2.11.26): מספר דקות לפני תחילת המפגש, 'day' מתחילת יום המפגש, 'always' תמיד. ברירת המחדל שעה לפני, כמו שהיה קבוע בקוד. להחליף __S__ ב-test או ב-public:
--   sed 's/__S__/test/g' admin/status-lead.sql | supabase db query --linked
--   sed 's/__S__/public/g' admin/status-lead.sql | supabase db query --linked
alter table __S__.harpatka_meeting_types add column if not exists status_lead text not null default '60';
notify pgrst, 'reload schema';
