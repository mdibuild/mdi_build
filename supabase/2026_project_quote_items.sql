create table public.project_quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.project_quotes(id) on delete cascade,
  label text not null,
  quantity numeric(12,3) not null default 0,
  unit text not null default 'u',
  unit_price numeric(14,2) not null default 0,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_project_quote_items_quote_id on public.project_quote_items(quote_id);

alter table public.project_quote_items enable row level security;

create policy company_select_project_quote_items on public.project_quote_items
for select using (
  exists (
    select 1 from public.project_quotes q
    join public.profiles p on p.company_id = q.company_id
    where q.id = project_quote_items.quote_id and p.id = auth.uid()
  )
);

create policy company_insert_project_quote_items on public.project_quote_items
for insert with check (
  exists (
    select 1 from public.project_quotes q
    join public.profiles p on p.company_id = q.company_id
    where q.id = project_quote_items.quote_id and p.id = auth.uid()
  )
);

create policy company_update_project_quote_items on public.project_quote_items
for update using (
  exists (
    select 1 from public.project_quotes q
    join public.profiles p on p.company_id = q.company_id
    where q.id = project_quote_items.quote_id and p.id = auth.uid()
  )
);

create policy company_delete_project_quote_items on public.project_quote_items
for delete using (
  exists (
    select 1 from public.project_quotes q
    join public.profiles p on p.company_id = q.company_id
    where q.id = project_quote_items.quote_id and p.id = auth.uid()
  )
);
