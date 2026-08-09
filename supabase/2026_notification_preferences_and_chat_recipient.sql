create table public.notification_preferences (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  module text not null check (module in ('planning', 'chat', 'achats')),
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (profile_id, module)
);

alter table public.notification_preferences enable row level security;

create policy own_notification_preferences on public.notification_preferences
for all using (profile_id = auth.uid())
with check (profile_id = auth.uid());

alter table public.project_chat_messages
  add column if not exists recipient_id uuid references public.profiles(id) on delete set null,
  add column if not exists recipient_name text;
