-- La migration précédente a ajouté legal_nif/legal_nis/legal_article_imposition
-- mais a oublié legal_rc, alors que le modèle Client/Supplier l'envoie déjà à
-- chaque enregistrement — colonne manquante, l'enregistrement échouait.
alter table public.clients add column if not exists legal_rc text not null default '';
alter table public.suppliers add column if not exists legal_rc text not null default '';
