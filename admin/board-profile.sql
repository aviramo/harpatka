-- הפרופיל כולל גם שם להצגה בלוח (שם המשתתף המקושר, אחרת שם חשבון הגוגל)
create or replace function public.harpatka_board_profile()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', m.status, 'can_share', m.participant_id is not null,
    'can_post', public.harpatka_is_admin() or exists (select 1 from public.harpatka_attendance at where at.participant_id = m.participant_id),
    'name', coalesce(pa.name, nullif(m.google_name, ''), m.email))
  from public.harpatka_members m left join public.harpatka_participants pa on pa.id = m.participant_id where m.user_id = auth.uid();
$$;
revoke all on function public.harpatka_board_profile() from public;
grant execute on function public.harpatka_board_profile() to authenticated;
