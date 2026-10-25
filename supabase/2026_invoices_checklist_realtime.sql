-- Facturation (fusionnée avec les devis), check-list et actualisation
-- automatique des écrans (temps réel). Ajouts uniquement : aucune donnée
-- existante n'est modifiée ni supprimée.

-- ---------------------------------------------------------------------------
-- 1) Factures
-- ---------------------------------------------------------------------------
create table if not exists public.project_invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  quote_id uuid references public.project_quotes(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  number text not null,
  title text not null default 'Facture',
  status text not null default 'brouillon'
    check (status in ('brouillon', 'emise', 'partielle', 'payee', 'annulee')),
  issue_date date not null default current_date,
  due_date date,
  tax_rate numeric(5,2) not null default 19,
  amount_paid numeric(14,2) not null default 0,
  notes text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, number)
);

create index if not exists idx_project_invoices_project on public.project_invoices(project_id);
create index if not exists idx_project_invoices_quote on public.project_invoices(quote_id);
create index if not exists idx_project_invoices_client on public.project_invoices(client_id);

create table if not exists public.project_invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.project_invoices(id) on delete cascade,
  label text not null,
  quantity numeric(12,3) not null default 0,
  unit text not null default 'u',
  unit_price numeric(14,2) not null default 0,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_project_invoice_items_invoice on public.project_invoice_items(invoice_id);

alter table public.project_invoices enable row level security;
alter table public.project_invoice_items enable row level security;

drop policy if exists project_invoices_company on public.project_invoices;
create policy project_invoices_company on public.project_invoices
for all using (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = project_invoices.company_id)
) with check (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = project_invoices.company_id)
);

drop policy if exists project_invoice_items_company on public.project_invoice_items;
create policy project_invoice_items_company on public.project_invoice_items
for all using (
  exists (select 1 from public.project_invoices i
          join public.profiles p on p.company_id = i.company_id
          where i.id = project_invoice_items.invoice_id and p.id = auth.uid())
) with check (
  exists (select 1 from public.project_invoices i
          join public.profiles p on p.company_id = i.company_id
          where i.id = project_invoice_items.invoice_id and p.id = auth.uid())
);

-- ---------------------------------------------------------------------------
-- 2) Check-list (liste de choses à faire, par chantier ou générale)
-- ---------------------------------------------------------------------------
create table if not exists public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  title text not null,
  is_done boolean not null default false,
  due_date date,
  client_id uuid references public.clients(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  sort_order int not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_checklist_items_company on public.checklist_items(company_id);
create index if not exists idx_checklist_items_project on public.checklist_items(project_id);

alter table public.checklist_items enable row level security;

drop policy if exists checklist_items_company on public.checklist_items;
create policy checklist_items_company on public.checklist_items
for all using (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = checklist_items.company_id)
) with check (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = checklist_items.company_id)
);

-- ---------------------------------------------------------------------------
-- 3) Temps réel : chaque nouvelle entrée actualise les écrans ouverts.
--    (Les règles de sécurité RLS s'appliquent aussi aux notifications.)
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'projects', 'spaces', 'space_openings', 'project_quotes',
    'project_quote_items', 'project_invoices', 'project_invoice_items',
    'purchases', 'purchase_items', 'project_tasks',
    'project_task_dependencies', 'project_documents', 'project_reports',
    'clients', 'suppliers', 'checklist_items'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
