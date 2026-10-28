-- v2.4 : accusés de réception et de lecture pour TOUS les messages du chat
-- (texte, photo, audio, fichier ; conversations de groupe et privées).
--   ✓      envoyé (enregistré sur le serveur)
--   ✓✓     reçu (arrivé sur le téléphone du ou des destinataires)
--   ✓✓ bleu lu
-- Ajouts uniquement : aucune donnée existante n'est modifiée ni supprimée.

alter table public.project_chat_messages
  add column if not exists delivered_at timestamptz,
  add column if not exists delivered_to uuid[] not null default '{}',
  add column if not exists read_by uuid[] not null default '{}';

-- Les accusés passent par ces deux fonctions : chacun ne peut que s'ajouter
-- lui-même, sur les messages de son entreprise qui ne viennent pas de lui
-- et qui lui sont visibles (groupe, ou privé qui lui est adressé). Aucune
-- autre colonne du message ne peut être modifiée par ce biais.
create or replace function public.chat_mark_delivered(message_ids uuid[])
returns void
language sql
security definer
set search_path = public
as $$
  update public.project_chat_messages m
     set delivered_to = array_append(m.delivered_to, auth.uid()),
         delivered_at = case
           when m.recipient_id = auth.uid() and m.delivered_at is null
             then now() else m.delivered_at end
   where m.id = any(message_ids)
     and m.sender_id is distinct from auth.uid()
     and not (auth.uid() = any(m.delivered_to))
     and (m.recipient_id is null or m.recipient_id = auth.uid())
     and m.company_id = (select p.company_id from public.profiles p
                         where p.id = auth.uid());
$$;

create or replace function public.chat_mark_read(message_ids uuid[])
returns void
language sql
security definer
set search_path = public
as $$
  update public.project_chat_messages m
     set read_by = case when auth.uid() = any(m.read_by)
                        then m.read_by else array_append(m.read_by, auth.uid()) end,
         delivered_to = case when auth.uid() = any(m.delivered_to)
                        then m.delivered_to else array_append(m.delivered_to, auth.uid()) end,
         read_at = case
           when m.recipient_id = auth.uid() and m.read_at is null
             then now() else m.read_at end,
         delivered_at = case
           when m.recipient_id = auth.uid() and m.delivered_at is null
             then now() else m.delivered_at end
   where m.id = any(message_ids)
     and m.sender_id is distinct from auth.uid()
     and not (auth.uid() = any(m.read_by))
     and (m.recipient_id is null or m.recipient_id = auth.uid())
     and m.company_id = (select p.company_id from public.profiles p
                         where p.id = auth.uid());
$$;

revoke all on function public.chat_mark_delivered(uuid[]) from public;
revoke all on function public.chat_mark_read(uuid[]) from public;
grant execute on function public.chat_mark_delivered(uuid[]) to authenticated;
grant execute on function public.chat_mark_read(uuid[]) to authenticated;
