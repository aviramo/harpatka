-- מייל לבעל הפוסט כשתגובה על הפוסט שלו מתפרסמת (אחרי אישור מנהל). הכתובת היא חשבון הגוגל שאיתו התחבר ללוח.
-- לא נשלח על תגובה של בעל הפוסט עצמו, ולא על תגובה שעוד ממתינה לאישור. המגיב נשאר אנונימי.
insert into public.harpatka_mail_templates (key, subject, html) values
('comment_published', 'תגובה חדשה על הפוסט שלך בלוח השיתופים', $t$<div dir="rtl" style="direction:rtl;text-align:right;background:#F6EFE4;padding:24px 12px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#FFFDF9;border-radius:24px;overflow:hidden;border:1px solid #E8D5BE">
<div style="background:#686A48;color:#ffffff;padding:20px 24px"><div style="font-size:14px;opacity:.9">לוח השיתופים</div><div style="font-size:22px;font-weight:bold;margin-top:4px">יש תגובה חדשה על הפוסט שלך</div></div>
<div style="padding:22px 24px 26px">
<div style="font-size:13px;color:#8A7F72;margin-bottom:6px">הפוסט שלך</div>
<div style="font-size:15px;color:#6b6155;line-height:1.5;border-right:3px solid #E8D5BE;padding-right:12px">{{post_snippet}}</div>
<div style="font-size:13px;color:#8A7F72;margin:18px 0 6px">התגובה</div>
<div style="background:#F6EFE4;border-radius:16px;padding:14px 16px;font-size:18px;line-height:1.5;color:#3F382F">{{{comment_html}}}</div>
{{{phone_note}}}
<a href="{{board_link}}" style="display:block;background:#C96F52;color:#ffffff;text-decoration:none;font-weight:bold;font-size:17px;text-align:center;padding:14px 20px;border-radius:999px;margin-top:20px">לצפייה ולתגובה בלוח</a>
</div></div></div>$t$)
on conflict (key) do nothing;

create or replace function public.harpatka_posts_notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare rt public.harpatka_posts; rm public.harpatka_members;
begin
  if new.parent_id is null or new.approved_at is null or new.deleted_at is not null then return new; end if;
  if tg_op = 'UPDATE' and old.approved_at is not null then return new; end if;
  select * into rt from public.harpatka_posts where id = new.root_id and deleted_at is null;
  if not found or rt.user_id = new.user_id then return new; end if;
  select * into rm from public.harpatka_members where user_id = rt.user_id and status = 'approved';
  if not found or coalesce(rm.email, '') = '' then return new; end if;
  perform public.harpatka_send_mail('comment_published', jsonb_build_object(
    'post_snippet', case when length(rt.body) > 140 then left(rt.body, 140) || '…' else rt.body end,
    'comment_html', replace(public.harpatka_html_esc(new.body), E'\n', '<br>'),
    'phone_note', case when new.share_phone then '<div style="margin-top:12px;font-size:15px;color:#1F5C3A;background:#E3F1E8;border-radius:12px;padding:10px 14px">המגיב/ה בחר/ה לשתף איתך את הטלפון. הוא מופיע מתחת לתגובה בלוח</div>' else '' end,
    'board_link', 'https://harpatka.co.il/board/'), rm.email);
  return new;
exception when others then return new;   -- כשל במייל לא פוגע בפרסום
end $$;
revoke all on function public.harpatka_posts_notify_comment() from public, anon, authenticated;
drop trigger if exists harpatka_posts_notify_comment on public.harpatka_posts;
create trigger harpatka_posts_notify_comment after insert or update of approved_at on public.harpatka_posts
  for each row execute function public.harpatka_posts_notify_comment();
