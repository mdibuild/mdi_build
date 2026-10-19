-- Liens clients / fournisseurs dans les modules (appliqué le 19/10/2026).
-- Colonnes facultatives : aucune donnée existante n'est modifiée.
-- Suppression d'un client/fournisseur : le lien est simplement vidé.

alter table public.projects
  add column if not exists client_id uuid references public.clients(id) on delete set null;
alter table public.project_quotes
  add column if not exists client_id uuid references public.clients(id) on delete set null;
alter table public.purchases
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.purchase_items
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.project_tasks
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.project_documents
  add column if not exists client_id uuid references public.clients(id) on delete set null,
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;

create index if not exists projects_client_id_idx on public.projects(client_id);
create index if not exists project_quotes_client_id_idx on public.project_quotes(client_id);
create index if not exists purchases_supplier_id_idx on public.purchases(supplier_id);
create index if not exists purchase_items_supplier_id_idx on public.purchase_items(supplier_id);
create index if not exists project_tasks_supplier_id_idx on public.project_tasks(supplier_id);
create index if not exists project_documents_client_id_idx on public.project_documents(client_id);
create index if not exists project_documents_supplier_id_idx on public.project_documents(supplier_id);
