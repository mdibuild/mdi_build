-- v2.3 : check-list avec échéance en date ET heure, destinataire parmi les
-- utilisateurs et rappel (notification). Ajouts uniquement.

alter table public.checklist_items
  -- Échéance précise (date + heure). La colonne due_date reste remplie
  -- avec le jour, pour compatibilité.
  add column if not exists due_at timestamptz,
  -- Utilisateur à qui la tâche est destinée.
  add column if not exists assigned_to uuid references auth.users(id) on delete set null,
  -- Rappel : nombre de minutes avant l'échéance (0 = à l'heure ; null =
  -- pas de rappel).
  add column if not exists reminder_minutes int default 0;

create index if not exists idx_checklist_items_assigned on public.checklist_items(assigned_to);
