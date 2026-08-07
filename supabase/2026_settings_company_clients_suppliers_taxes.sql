-- À exécuter dans l'éditeur SQL de ton projet Supabase (Dashboard > SQL Editor).
-- Ajoute : profil entreprise étendu, référentiels clients/fournisseurs, taux de TVA,
-- et le bucket de stockage pour le logo entreprise.

-- Extension de la fiche entreprise existante
alter table public.companies
  add column if not exists legal_ice text,
  add column if not exists legal_if text,
  add column if not exists legal_rc text,
  add column if not exists legal_patente text,
  add column if not exists logo_path text,
  add column if not exists bank_name text,
  add column if not exists bank_rib text,
  add column if not exists updated_at timestamptz not null default now();

-- Référentiel clients
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  contact_name text,
  phone text,
  email text,
  address text,
  tax_id text,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Référentiel fournisseurs (même forme que clients)
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  contact_name text,
  phone text,
  email text,
  address text,
  tax_id text,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Taux de TVA / taxes
create table public.tax_rates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  label text not null,
  rate numeric(6,3) not null,
  is_default boolean not null default false,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_clients_company_id on public.clients(company_id);
create index idx_suppliers_company_id on public.suppliers(company_id);
create index idx_tax_rates_company_id on public.tax_rates(company_id);

alter table public.clients enable row level security;
alter table public.suppliers enable row level security;
alter table public.tax_rates enable row level security;

create policy company_all_clients on public.clients
for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = clients.company_id)
) with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = clients.company_id)
);

create policy company_all_suppliers on public.suppliers
for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = suppliers.company_id)
) with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = suppliers.company_id)
);

create policy company_all_tax_rates on public.tax_rates
for all using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = tax_rates.company_id)
) with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.company_id = tax_rates.company_id)
);

-- Storage bucket pour le logo entreprise (lecture publique, écriture authentifiée)
insert into storage.buckets (id, name, public)
values ('company-logos', 'company-logos', true)
on conflict (id) do nothing;

create policy company_logo_read on storage.objects
for select using (bucket_id = 'company-logos');

create policy company_logo_write on storage.objects
for all using (bucket_id = 'company-logos' and auth.role() = 'authenticated')
with check (bucket_id = 'company-logos' and auth.role() = 'authenticated');

-- La table companies a RLS activé depuis le schéma initial mais n'a jamais eu de
-- policy définie (contrairement à projects/spaces/...) : sans ça, toute lecture/
-- écriture via le client renvoie 0 ligne silencieusement, d'où l'erreur PGRST116
-- rencontrée sur la page Entreprise.
create policy company_select_own on public.companies
for select using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = companies.id
  )
);

create policy company_update_own on public.companies
for update using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = companies.id
  )
) with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.company_id = companies.id
  )
);
