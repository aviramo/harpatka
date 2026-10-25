-- מייל הרשמה חדשה למנהלים: בלי שורת הטלפון (יש כפתור וואטסאפ) ובלי שעת ההרשמה (זו שעת קבלת המייל)
update public.harpatka_mail_templates set html = $tpl$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#C96F52;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div><div style="font-size:22px;font-weight:bold;margin-top:4px">הרשמה חדשה מהאתר</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:26px;font-weight:bold;color:#3F382F;margin-bottom:14px">{{name}}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse">
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">גיל</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{age}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מגדר</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{gender}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#8A7F72;font-size:14px">מפגש</td><td style="padding:10px 0;border-top:1px solid #E8D5BE;color:#3F382F;font-size:17px;font-weight:bold">{{meeting}}</td></tr>
</table>
<a href="{{wa_link}}" style="display:block;background:#25A55F;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">שליחת וואטסאפ</a>
<a href="{{admin_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:12px">הפרטים בדף הניהול</a>
</div></div></div>$tpl$ where key = 'signup';
