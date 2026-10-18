-- Chat général (hors projet).
-- Un message dont project_id est NULL appartient au chat général de
-- l'entreprise ; un message avec project_id reste dans la conversation de ce
-- projet. Les deux historiques ne se mélangent jamais.
--
-- Données existantes : aucune ligne modifiée (tous les messages actuels ont un
-- projet et y restent rattachés).
--
-- Droits : aucun changement nécessaire. Les règles existantes de
-- project_chat_messages (select / insert / update / delete) sont fondées sur
-- l'entreprise (company_id), donc s'appliquent aussi au chat général. Le
-- stockage « project-documents » accepte déjà le dossier chat/general/…
-- Le déclencheur notify_new_chat_message n'utilise pas project_id.

alter table public.project_chat_messages
  alter column project_id drop not null;
