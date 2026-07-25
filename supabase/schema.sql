create extension if not exists "pgcrypto";

create type public.user_role as enum ('directeur', 'chef_projet', 'acheteur');
create type public.record_status as enum ('brouillon', 'en_cours', 'valide', 'annule', 'termine', 'archive');
create type public.space_type as enum ('piece', 'facade', 'toiture', 'fondation', 'cloture', 'espace_exterieur');

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  full_name text not null,
  email text not null,
  role public.user_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  client_name text,
  location text,
  description text,
  budget_initial numeric(14,2) not null default 0,
  progress numeric(5,2) not null default 0,
  status public.record_status not null default 'brouillon',
  created_at timestamptz not null default now()
);

create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  type public.space_type not null,
  name text not null,
  level_name text,
  length numeric(12,3) not null default 0,
  width numeric(12,3) not null default 0,
  height numeric(12,3) not null default 0,
  quantity numeric(12,3) not null default 1,
  status public.record_status not null default 'brouillon',
  created_at timestamptz not null default now()
);

create table public.space_openings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  space_id uuid not null references public.spaces(id) on delete cascade,
  name text not null,
  opening_type text not null,
  width numeric(12,3) not null,
  height numeric(12,3) not null,
  quantity numeric(12,3) not null default 1,
  created_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now()
);

create index idx_projects_company_id on public.projects(company_id);
create index idx_spaces_project_id on public.spaces(project_id);
create index idx_space_openings_space_id on public.space_openings(space_id);

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.spaces enable row level security;
alter table public.space_openings enable row level security;
alter table public.device_tokens enable row level security;

create policy company_select_projects on public.projects
for select using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = projects.company_id
  )
);

create policy company_insert_projects on public.projects
for insert with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = projects.company_id
  )
);

create policy company_update_projects on public.projects
for update using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = projects.company_id
  )
);

create policy company_delete_projects on public.projects
for delete using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = projects.company_id
  )
);

create policy company_select_spaces on public.spaces
for select using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = spaces.company_id
  )
);

create policy company_insert_spaces on public.spaces
for insert with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = spaces.company_id
  )
);

create policy company_update_spaces on public.spaces
for update using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = spaces.company_id
  )
);

create policy company_delete_spaces on public.spaces
for delete using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = spaces.company_id
  )
);

create policy company_select_space_openings on public.space_openings
for select using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = space_openings.company_id
  )
);

create policy company_insert_space_openings on public.space_openings
for insert with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = space_openings.company_id
  )
);

create policy company_update_space_openings on public.space_openings
for update using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = space_openings.company_id
  )
);

create policy company_delete_space_openings on public.space_openings
for delete using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = space_openings.company_id
  )
);
