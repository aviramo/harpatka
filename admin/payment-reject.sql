-- דחיית דיווח תשלום (29.10.26): מנהל דוחה דיווח ("שילמתי") מהפופאפ של ההקצאה. אידמפוטנטי; להריץ על public ואז admin/test-site.sql (העמודה גם ב-test).
-- עמודה pay_rejected_at: מנקה את הדיווח (pay_reported_at) ומסמנת דחייה; מוצגת באזור האישי ובדף הבית ("הדיווח לא אושר"), מתאפסת בדיווח חדש או בתשלום שנרשם.
alter table public.harpatka_attendance add column if not exists pay_rejected_at timestamptz;
alter table test.harpatka_attendance add column if not exists pay_rejected_at timestamptz;

insert into public.harpatka_mail_templates (key, subject, html)
select 'payment_rejected', 'לא הצלחנו לאמת את התשלום שדיווחת',
$h$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#C96F52;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">יוצאים להרפתקה</div><div style="font-size:22px;font-weight:bold;margin-top:4px">לא הצלחנו לאמת את התשלום</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:20px;font-weight:bold;color:#3F382F;margin-bottom:12px">היי {{first_name}},</div>
<div style="font-size:16px;line-height:1.6;color:#3F382F;margin-bottom:12px">קיבלנו את הדיווח ששילמת למפגש ב-{{meeting}}, אבל לא מצאנו אצלנו תשלום תואם. ייתכן שההעברה עוד בדרך, או שנפלה טעות קטנה בדרך.</div>
<div style="font-size:16px;line-height:1.6;color:#3F382F;margin-bottom:18px">המקום שלך עדיין לא שמור. אפשר להיכנס לאזור האישי, להשלים את התשלום ולדווח מחדש. ואם יש שאלה, פשוט עונים לנו בוואטסאפ ונסדר הכול.</div>
<a href="{{me_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px">לאזור האישי</a>
</div></div></div>$h$
where not exists (select 1 from public.harpatka_mail_templates where key = 'payment_rejected');

-- תשלום שנרשם למפגש מנקה גם דיווח וגם דחייה של אותו שיוך
create or replace function public.harpatka_clear_pay_reported() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.meeting_id is not null and new.kind = 'payment' then
    update public.harpatka_attendance set pay_reported_at = null, pay_rejected_at = null
      where participant_id = new.participant_id and meeting_id = new.meeting_id and (pay_reported_at is not null or pay_rejected_at is not null);
  end if;
  return new;
end $$;

-- דחייה: הערת מערכת ומייל למשתתף (רק אם יש לו חשבון מחובר עם אימייל; בלי אימייל הדחייה עדיין מוצגת באזור האישי ובדף הבית)
create or replace function public.harpatka_att_reject_notify() returns trigger
language plpgsql security definer set search_path = public as $$
declare mt public.harpatka_meetings; pa public.harpatka_participants; em text;
begin
  if new.pay_rejected_at is null or new.pay_rejected_at is not distinct from old.pay_rejected_at then return new; end if;
  select * into mt from public.harpatka_meetings where id = new.meeting_id;
  select * into pa from public.harpatka_participants where id = new.participant_id;
  begin
    perform public.harpatka_sys_note(new.participant_id, 'דיווח התשלום נדחה למפגש ' || public.harpatka_meeting_short(new.meeting_id), 'payment_rejected', new.meeting_id, null, null, old.pay_reported_amount);
  exception when others then null;
  end;
  begin
    select lower(m.email) into em from public.harpatka_members m where m.participant_id = new.participant_id and coalesce(m.email, '') <> '' order by (m.status = 'approved') desc limit 1;
    if em is not null then
      perform public.harpatka_send_mail('payment_rejected', jsonb_build_object(
        'first_name', coalesce(nullif(pa.first_name, ''), pa.name, ''),
        'meeting', to_char(mt.meeting_date, 'DD.MM') || ' · ' || to_char(mt.meeting_time, 'HH24:MI') || coalesce(' · ' || nullif(mt.city, ''), ''),
        'me_link', 'https://harpatka.co.il/me/?m=' || new.meeting_id), em);
    end if;
  exception when others then null;   -- כשל במייל לא מבטל את הדחייה
  end;
  return new;
end $$;
revoke all on function public.harpatka_att_reject_notify() from public, anon, authenticated;
drop trigger if exists harpatka_att_reject_notify on public.harpatka_attendance;
create trigger harpatka_att_reject_notify after update of pay_rejected_at on public.harpatka_attendance
  for each row execute function public.harpatka_att_reject_notify();
