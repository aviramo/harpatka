-- מינוח "שמירת מקום" במקום "הרשמה" במיילים למשתתף (7.11.26). אידמפוטנטי; לרוץ על test ואז על public (sed 's/__S__/test/g').
-- meeting_registered: "שמרת מקום למפגש, נשאר לשלם"; meeting_removed: "שמירת המקום שלך למפגש בוטלה". לשון יחיד, כמו שאר המיילים ("שלך", "לך").
update __S__.harpatka_mail_templates set
  subject = replace(subject, 'נרשמת למפגש, נשאר לשלם', 'שמרת מקום למפגש, נשאר לשלם'),
  html    = replace(html, '>נרשמת למפגש:</div>', '>שמרת מקום למפגש:</div>')
where key = 'meeting_registered';
update __S__.harpatka_mail_templates set
  subject = replace(subject, 'הרישום שלך למפגש בוטל', 'שמירת המקום שלך למפגש בוטלה'),
  html    = replace(html, '>הרישום שלך למפגש הזה בוטל:</div>', '>שמירת המקום שלך למפגש הזה בוטלה:</div>')
where key = 'meeting_removed';
