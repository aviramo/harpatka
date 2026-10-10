/* הגדרות משותפות לכל העמודים (עמוד הבית, v6, ביודנסה). עמוד יכול לדרוס ערך אחרי טעינת הקובץ, למשל CONFIG.hadarMessage */
const CONFIG = {
  supabaseUrl: 'https://ezakarwqstnldqixgreb.supabase.co',     // Supabase הייעודי של הפרויקט (harpatka_meetings / harpatka_signup)
  supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6YWthcndxc3RubGRxaXhncmViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMTA3MzIsImV4cCI6MjEwNjc4NjczMn0.Bg0eFBC4zKjyJc5kBw3wLgSP-PkxLFVv3o7-4YUdq4c',                  // מפתח ציבורי (anon)
  whatsappOfir: '972587078708',                   // מספר הנייד של אופיר (פורמט בינ"ל, בלי +)
  whatsappHadar: '972546163012',                  // מספר הנייד של הדר — יעד כל כפתורי "אני רוצה להצטרף"
  hadarMessage: 'היי הדר, מסקרן אותי הקונספט שלכם',
  ofirMessage: 'היי אופיר, מסקרן אותי הקונספט שלכם',
  updatesGroupLink: 'https://chat.whatsapp.com/HPBClkrbondA3JlQyOvseI',            // קבוצת העדכונים עד גיל 50
  updatesGroup50PlusLink: 'https://chat.whatsapp.com/DB7zVc2NdVXEquZCC6PpUP',      // קבוצת העדכונים גיל 50 ומעלה
  payboxLink: 'https://links.payboxapp.com/zwi4JG24Y6b',
  sheetsEndpoint: 'https://script.google.com/macros/s/AKfycbzTGo8SNjyF-xJsn08PXWrYt6EdkZOlmOCXeeFnlMHvg7uyMxXR6i8IoemuiBJTZE-EPQ/exec',
  pixelId: '429806621602468',
};
