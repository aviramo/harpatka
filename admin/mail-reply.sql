-- מייל גם למי שהגיבו לתגובה שלו (אם הוא לא המגיב). בעל הפוסט ממשיך לקבל על כל תגובה בפוסט שלו (comment_published),
-- ובתגובה לתגובה: בעל התגובה מקבל reply_published, ובעל הפוסט מקבל comment_published רק אם הוא לא אותו אדם.
insert into public.harpatka_mail_templates (key, subject, html)
select 'reply_published', 'הגיבו לתגובה שלך בלוח השיתופים',
  replace(replace(replace(html, 'יש תגובה חדשה על הפוסט שלך', 'הגיבו לתגובה שלך'), '>הפוסט שלך<', '>התגובה שלך<'), '>התגובה<', '>התגובה החדשה<')
from public.harpatka_mail_templates where key = 'comment_published' on conflict (key) do nothing;

create or replace function public.harpatka_posts_notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare rt public.harpatka_posts; par public.harpatka_posts; rm public.harpatka_members; pm public.harpatka_members; vars jsonb;
begin
  if new.parent_id is null or new.approved_at is null or new.deleted_at is not null then return new; end if;
  if tg_op = 'UPDATE' and old.approved_at is not null then return new; end if;
  select * into rt from public.harpatka_posts where id = new.root_id and deleted_at is null;
  if not found then return new; end if;
  select * into par from public.harpatka_posts where id = new.parent_id;
  vars := jsonb_build_object(
    'comment_html', replace(public.harpatka_html_esc(new.body), E'\n', '<br>'),
    'phone_note', case when new.share_phone then '<div style="margin-top:12px;font-size:15px;color:#1F5C3A;background:#E3F1E8;border-radius:12px;padding:10px 14px">המגיב/ה בחר/ה לשתף איתך את הטלפון. הוא מופיע מתחת לתגובה בלוח</div>' else '' end,
    'board_link', 'https://harpatka.co.il/board/');
  -- תגובה לתגובה: מייל לבעל התגובה שהגיבו לה
  if par.id is not null and par.parent_id is not null and par.user_id <> new.user_id then
    select * into pm from public.harpatka_members where user_id = par.user_id and status = 'approved';
    if found and coalesce(pm.email, '') <> '' then
      perform public.harpatka_send_mail('reply_published', vars || jsonb_build_object('post_snippet', case when length(par.body) > 140 then left(par.body, 140) || '…' else par.body end), pm.email);
    end if;
  end if;
  -- בעל הפוסט: על כל תגובה בפוסט שלו, חוץ ממי שכבר קיבל מייל כבעל התגובה, וחוץ מהמגיב עצמו
  if rt.user_id <> new.user_id and not (par.id is not null and par.parent_id is not null and par.user_id = rt.user_id) then
    select * into rm from public.harpatka_members where user_id = rt.user_id and status = 'approved';
    if found and coalesce(rm.email, '') <> '' then
      perform public.harpatka_send_mail('comment_published', vars || jsonb_build_object('post_snippet', case when length(rt.body) > 140 then left(rt.body, 140) || '…' else rt.body end), rm.email);
    end if;
  end if;
  return new;
exception when others then return new;
end $$;
