-- ==========================================================================
-- תבניות המיילים בעיצוב החדש (30.10.26): רקע לבן, בלי פינות מעוגלות, פלטת האתר החדשה.
-- פס טרקוטה עליון (#E5562D), בלי רצועת כותרת צבעונית: שם המותג בטרקוטה כהה עם ריבוע קטן ומתחתיו הכותרת בדיו (#2C231D),
-- קווים דקים בגוון הדיו השקוף, ציטוטים ברקע שמנת (#FFF5E8) עם קו טרקוטה, כפתורים מרובעים:
-- ראשי טרקוטה כהה (#C8411B), וואטסאפ בזית (#4E7D2C), הסתרה כמסגרת דיו.
-- עובד על כל התבניות בטבלה באמצעות החלפות (אידמפוטנטי: אחרי ההרצה הערכים הישנים כבר לא קיימים).
-- נכתב ל-public; בסביבת הבדיקות מורץ אחרי החלפת public.harpatka_ ב-test.harpatka_.
-- ==========================================================================
update public.harpatka_mail_templates set html =
  replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
  regexp_replace(html,
    '<div style="background:#[0-9A-Fa-f]{6};color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:\.9">([^<]*)</div><div style="font-size:22px;font-weight:bold;margin-top:4px">([^<]*)</div></div>',
    '<div style="padding:22px 4px 4px"><div style="font-size:14px;font-weight:bold;color:#C8411B"><span style="display:inline-block;width:9px;height:9px;background:#E5562D;margin-left:8px;vertical-align:middle"></span>\1</div><div style="font-size:24px;font-weight:bold;color:#2C231D;margin-top:8px;line-height:1.3">\2</div></div>', 'g'),
  'background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif', 'background:#FFFFFF;padding:24px 16px;font-family:Arial,Helvetica,sans-serif;color:#2C231D'),
  'max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE', 'max-width:520px;margin:0 auto;background:#FFFFFF;border-top:4px solid #E5562D'),
  'padding:22px 24px 26px', 'padding:16px 4px 24px'),
  'background:#F6EFE4;border-radius:16px;', 'background:#FFF5E8;border-right:3px solid #E5562D;'),
  'border-right:3px solid #E8D5BE', 'border-right:3px solid #FFD8AE'),
  'border-top:1px solid #E8D5BE', 'border-top:1px solid rgba(44,35,29,.14)'),
  'background:#C96F52;color:#ffffff;', 'background:#C8411B;color:#ffffff;'),
  'background:#686A48;color:#ffffff;', 'background:#C8411B;color:#ffffff;'),
  'background:#25A55F;color:#ffffff;', 'background:#4E7D2C;color:#ffffff;'),
  'background:#663F4C;color:#ffffff;', 'background:#FFFFFF;color:#2C231D;border:1px solid #2C231D;'),
  'border-radius:999px', 'border-radius:0'),
  'border-radius:12px', 'border-radius:0'),
  '#3F382F', '#2C231D'),
  '#8A7F72', '#4A3D33'),
  '#6b6155', '#4A3D33'),
  'max-width:480px', 'max-width:520px');
