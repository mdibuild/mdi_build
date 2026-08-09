-- Entreprise : remplace les identifiants marocains (ICE/IF/Patente) par les
-- identifiants algériens (NIF/NIS/RC/Article d'imposition). legal_ice est
-- laissée en place (non détruite) mais n'est plus utilisée par l'app.
alter table public.companies rename column legal_if to legal_nif;
alter table public.companies rename column legal_patente to legal_article_imposition;
alter table public.companies add column if not exists legal_nis text not null default '';

-- Clients : ajoute le type d'entité (particulier/entreprise) et les
-- identifiants légaux, en reprenant l'ancien tax_id dans le NIF s'il existait.
alter table public.clients add column if not exists entity_type text not null default 'entreprise';
alter table public.clients add column if not exists legal_nif text not null default '';
alter table public.clients add column if not exists legal_nis text not null default '';
alter table public.clients add column if not exists legal_article_imposition text not null default '';
update public.clients set legal_nif = tax_id where tax_id is not null and tax_id <> '' and legal_nif = '';

-- Fournisseurs : même traitement que les clients.
alter table public.suppliers add column if not exists entity_type text not null default 'entreprise';
alter table public.suppliers add column if not exists legal_nif text not null default '';
alter table public.suppliers add column if not exists legal_nis text not null default '';
alter table public.suppliers add column if not exists legal_article_imposition text not null default '';
update public.suppliers set legal_nif = tax_id where tax_id is not null and tax_id <> '' and legal_nif = '';
