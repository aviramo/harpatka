-- שליחת מיילים דרך Resend (מהדומיין של האתר) כשמוגדרים resend_key ו-mail_from ב-harpatka_settings; אחרת הנתיב הקודם (Apps Script).
-- ההגדרות (מפתח ה-API לא נשמר בקוד): 
--   insert into public.harpatka_settings (key, value) values ('resend_key', 're_...'), ('mail_from', 'יוצאים להרפתקה <no-reply@mail.harpatka.co.il>')
--   on conflict (key) do update set value = excluded.value;
create or replace function public.harpatka_send_mail(p_key text, p_vars jsonb default '{}', p_to text default null, p_extra jsonb default '{}')
returns void language plpgsql security definer set search_path = public as $$
declare u text; tok text; t public.harpatka_mail_templates; dflt text; recip text; rk text; fr text;
begin
  select * into t from public.harpatka_mail_templates where key = p_key;
  if not found then return; end if;
  select value into dflt from public.harpatka_settings where key = 'mail_to';
  recip := coalesce(nullif(p_to, ''), nullif(t.to_addr, ''), nullif(dflt, ''));
  select value into rk from public.harpatka_settings where key = 'resend_key';
  select value into fr from public.harpatka_settings where key = 'mail_from';
  if coalesce(rk, '') <> '' and coalesce(fr, '') <> '' then
    if coalesce(recip, '') = '' then return; end if;
    perform net.http_post(
      url := 'https://api.resend.com/emails',
      body := jsonb_build_object('from', fr, 'to', to_jsonb(string_to_array(replace(recip, ' ', ''), ',')),
                'subject', public.harpatka_render(t.subject, p_vars, false), 'html', public.harpatka_render(t.html, p_vars, true)),
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || rk),
      timeout_milliseconds := 30000);
    return;
  end if;
  select value into u   from public.harpatka_settings where key = 'notify_url';
  select value into tok from public.harpatka_settings where key = 'notify_token';
  if coalesce(u, '') = '' then return; end if;
  perform net.http_post(
    url := u,
    body := coalesce(p_extra, '{}'::jsonb) || jsonb_build_object('token', tok, 'to', recip,
              'subject', public.harpatka_render(t.subject, p_vars, false), 'html', public.harpatka_render(t.html, p_vars, true)),
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 30000);
exception when others then
  null;
end $$;
revoke all on function public.harpatka_send_mail(text, jsonb, text, jsonb) from public, anon, authenticated;
insert into public.harpatka_settings (key, value) values ('mail_to', 'ofir.aviram@gmail.com,luriahadar@gmail.com') on conflict (key) do nothing;
