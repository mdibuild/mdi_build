-- Chat : accusés de lecture (read_at) + édition de message (edited_at)

alter table public.project_chat_messages
  add column if not exists read_at timestamptz,
  add column if not exists edited_at timestamptz;

-- Droit de mise à jour :
--   * l'expéditeur peut modifier son propre message (édition) ;
--   * le destinataire peut marquer le message comme lu (read_at).
drop policy if exists chat_update_sender_or_recipient
  on public.project_chat_messages;

create policy chat_update_sender_or_recipient
  on public.project_chat_messages
  for update
  to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid())
  with check (sender_id = auth.uid() or recipient_id = auth.uid());
