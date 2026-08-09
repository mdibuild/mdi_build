drop policy if exists company_select_profiles on public.profiles;

create or replace function public.current_user_company_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

create policy company_select_profiles on public.profiles
for select using (
  company_id = public.current_user_company_id()
);
