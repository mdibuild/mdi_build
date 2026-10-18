-- Notifications en double : chaque message de chat et chaque changement de
-- statut d'achat était notifié deux fois :
--   1) par l'application (fonction notify-event) : module indiqué (pour
--      ouvrir le bon écran), préférences de notification et messages privés
--      respectés ;
--   2) par ces déclencheurs (fonction send-push) : sans module, sans
--      préférences, et un message privé était notifié à toute l'entreprise.
-- On désactive les déclencheurs (sans les supprimer).
--
-- Retour arrière si besoin :
--   alter table public.project_chat_messages enable trigger trg_notify_new_chat_message;
--   alter table public.purchases enable trigger trg_notify_purchase_status_change;

alter table public.project_chat_messages
  disable trigger trg_notify_new_chat_message;

alter table public.purchases
  disable trigger trg_notify_purchase_status_change;
