-- v2.1 : remises et colonnes affichables (devis, factures), quantités
-- importées depuis Excel, suivi des achats (historique, n° de commande,
-- devis / proforma fournisseur). Ajouts uniquement : aucune donnée existante
-- n'est modifiée ni supprimée.

-- ---------------------------------------------------------------------------
-- 1) Remises et colonnes affichées sur les documents
-- ---------------------------------------------------------------------------
alter table public.project_quote_items
  add column if not exists discount_percent numeric(5,2) not null default 0;
alter table public.project_quotes
  add column if not exists discount_percent numeric(5,2) not null default 0,
  add column if not exists hidden_columns text[] not null default '{}';

alter table public.project_invoice_items
  add column if not exists discount_percent numeric(5,2) not null default 0;
alter table public.project_invoices
  add column if not exists discount_percent numeric(5,2) not null default 0,
  add column if not exists hidden_columns text[] not null default '{}';

-- ---------------------------------------------------------------------------
-- 2) Quantités importées (Excel) dans le Quantitatif
-- ---------------------------------------------------------------------------
create table if not exists public.project_quantity_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  label text not null,
  quantity numeric(14,3) not null default 0,
  unit text not null default 'u',
  unit_price numeric(14,2),
  total numeric(16,2),
  source_file text not null default '',
  sort_order int not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_project_quantity_items_project
  on public.project_quantity_items(project_id);

alter table public.project_quantity_items enable row level security;

drop policy if exists project_quantity_items_company on public.project_quantity_items;
create policy project_quantity_items_company on public.project_quantity_items
for all using (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = project_quantity_items.company_id)
) with check (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = project_quantity_items.company_id)
);

-- ---------------------------------------------------------------------------
-- 3) Suivi des achats
-- ---------------------------------------------------------------------------
-- Étape « pris en charge par l'acheteur » entre le besoin et la commande.
alter type public.purchase_status add value if not exists 'en_traitement' after 'dg_valide';

-- Numéro de commande (BC-AAAA-NNN), attribué au passage en « Commandé ».
alter table public.purchases
  add column if not exists order_number text;

-- Pièce jointe « devis / facture proforma du fournisseur ».
alter type public.project_document_category add value if not exists 'proforma' after 'bon_commande';

-- Historique : qui a fait quoi et quand (besoin, prise en charge,
-- commande, modification, pièce jointe, commentaire…).
create table if not exists public.purchase_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  kind text not null default 'commentaire'
    check (kind in ('creation', 'statut', 'modification', 'piece_jointe', 'commentaire')),
  status text,
  comment text not null default '',
  actor_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists idx_purchase_events_purchase on public.purchase_events(purchase_id);

alter table public.purchase_events enable row level security;

drop policy if exists purchase_events_company on public.purchase_events;
create policy purchase_events_company on public.purchase_events
for all using (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = purchase_events.company_id)
) with check (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.company_id = purchase_events.company_id)
);

-- ---------------------------------------------------------------------------
-- 4) Temps réel pour les nouvelles tables
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['project_quantity_items', 'purchase_events'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
