-- מספר וואטסאפ אחד לשני המנחים (3.11.26): הוואטסאפ העסקי של יוצאים להרפתקה, 055-258-9829.
-- המספר למיילים נמצא רק ב-harpatka_wa_vars. באתר: CONFIG.whatsapp ב-shared/config.js.
-- להרצה עם החלפה: sed 's/__S__/test/g' (ואחר כך public). אידמפוטנטי. מיילים שכבר נשלחו (harpatka_mail_log) לא משתנים.

create or replace function __S__.harpatka_wa_vars() returns jsonb language sql immutable as $$
  select jsonb_build_object('wa', 'https://wa.me/972552589829', 'wa_num', '055-258-9829')
$$;

do $do$
declare
  f text; d text;
  old text := $o$, 'wa_hadar', 'https://wa.me/972546163012', 'wa_ofir', 'https://wa.me/972587078708')$o$;
begin
  foreach f in array array['harpatka_mail_common', 'harpatka_pay_mail'] loop
    select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = '__S__' and p.proname = f;
    if position(old in d) > 0 then
      execute replace(d, old, ') || __S__.harpatka_wa_vars()');
    elsif position('wa_hadar' in d) > 0 then
      raise exception 'לא נמצא הנוסח הצפוי ב-%', f;
    end if;
  end loop;
end $do$;

update __S__.harpatka_mail_templates set html = replace(html,
    $t$<span style="white-space:nowrap"><a href="{{wa_hadar}}" style="color:#C8411B;font-weight:bold">הדר</a> · <a href="{{wa_ofir}}" style="color:#C8411B;font-weight:bold">אופיר</a></span>$t$,
    $t$<a href="{{wa}}" dir="ltr" style="color:#C8411B;font-weight:bold;white-space:nowrap">{{wa_num}}</a>$t$)
  where html like '%{{wa_hadar}}%';

do $do$
begin
  if exists (select 1 from __S__.harpatka_mail_templates where html ~ 'wa_hadar|wa_ofir') then
    raise exception 'נשארו תבניות עם המשתנים הישנים';
  end if;
end $do$;
