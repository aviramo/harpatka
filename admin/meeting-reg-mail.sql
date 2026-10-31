-- מייל למנהלים על כל הרשמה של משתתף למפגש (שיוך חדש ב-harpatka_attendance), גם של משתתף קיים:
-- טופס ההרשמה באתר (harpatka_signup), הרשמה בלחיצה של משתתף מחובר (harpatka_me_register), חיבור בטלפון (harpatka_me_phone) ועוד.
-- בלי מייל: (1) שיוך שמנהל עשה (דף הניהול, או צפייה כמשתתף); (2) משתתף שנוצר או חזר לפעילות באותה פעולה,
-- כי אז כבר נשלח המייל "הרשמה חדשה מהאתר" (harpatka_notify_signup) עם המפגש. אידמפוטנטי.
-- בסביבת הבדיקות: להריץ אחרי החלפת public.harpatka_ ב-test.harpatka_ (חוץ מ-harpatka_admins, שנשארת ב-public); שם המיילים יוצאים רק לאופיר.

create or replace function public.harpatka_att_reg_mail() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare p record; em text; nm text; disp text;
begin
  em := lower(coalesce(auth.jwt() ->> 'email', ''));
  if em <> '' and exists (select 1 from public.harpatka_admins a where lower(a.email) = em) then return new; end if;   -- שיוך שמנהל עשה: בלי מייל
  select id, first_name, last_name, phone_norm, age, gender, xmin::text as xm into p from public.harpatka_participants where id = new.participant_id;
  if p.id is null then return new; end if;
  if p.xm = (txid_current() % 4294967296)::text then return new; end if;   -- המשתתף נוצר או חזר לפעילות בפעולה הזו: כבר נשלח "הרשמה חדשה מהאתר" עם המפגש
  disp := case when p.phone_norm like '+972%' then '0' || substr(p.phone_norm, 5) else coalesce(p.phone_norm, '') end;
  nm := nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '');
  perform public.harpatka_send_mail('meeting_signup', jsonb_build_object(
    'name', coalesce(nm, disp),
    'age', coalesce(p.age::text, 'לא צוין'),
    'gender', case p.gender when 'male' then 'גבר' when 'female' then 'אישה' else 'לא צוין' end,
    'meeting', public.harpatka_meeting_label(new.meeting_id),
    'via', case when auth.uid() is null then 'טופס ההרשמה באתר' else 'חשבון גוגל (מחובר)' end,
    'wa_link', 'https://wa.me/' || regexp_replace(coalesce(p.phone_norm, ''), '\D', '', 'g'),
    'admin_link', 'https://harpatka.co.il/admin/?m=' || new.meeting_id || '&p=' || new.participant_id));
  return new;
exception when others then return new;   -- תקלה במייל לא פוגעת בהרשמה
end $fn$;

-- התבנית: אותו עיצוב כמו "הרשמה חדשה מהאתר", בכותרת "הרשמה למפגש" ועם שורת "דרך"
insert into public.harpatka_mail_templates (key, subject, html)
select 'meeting_signup', 'הרשמה למפגש: {{name}}',
  replace(replace(html, '>הרשמה חדשה מהאתר</div>', '>הרשמה למפגש</div>'),
    '{{meeting}}</td></tr>',
    '{{meeting}}</td></tr>
<tr><td style="padding:10px 0;border-top:1px solid rgba(44,35,29,.14);color:#4A3D33;font-size:14px">דרך</td><td style="padding:10px 0;border-top:1px solid rgba(44,35,29,.14);color:#2C231D;font-size:17px;font-weight:bold">{{via}}</td></tr>')
from public.harpatka_mail_templates where key = 'signup'
on conflict (key) do update set subject = excluded.subject, html = excluded.html;

do $$
declare s text;
begin
  foreach s in array array['public', 'test'] loop
    if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = s and p.proname = 'harpatka_att_reg_mail') then
      execute format('drop trigger if exists harpatka_att_reg_mail on %I.harpatka_attendance', s);
      execute format('create trigger harpatka_att_reg_mail after insert on %I.harpatka_attendance for each row execute function %I.harpatka_att_reg_mail()', s, s);
    end if;
  end loop;
end $$;
