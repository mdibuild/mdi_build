**Filtres, navigation chantier et actualisation — 21 octobre 2026**

Les changements sont intégrés à l’application Flutter. La maquette précédente reste indépendante.

Chaque module affiche désormais sous son titre une barre avec le champ **Sélection du projet**, les raccourcis vers les modules du chantier et le bouton **Actualiser**. Cette barre appartient au module et reste visible pendant le chargement, en cas d’erreur et sur mobile. La sélection est partagée : changer de chantier dans Planning conserve ce choix en ouvrant Métré ou Quantitatif. L’actualisation relit les données sans recharger le navigateur et conserve les filtres et la sélection. Les anciens sélecteurs en doublon sont masqués.

| Module | Filtres disponibles |
| --- | --- |
| Tableau de bord | Chantier, recherche d’indicateur/rapport, vue Indicateurs ou Activité et rapports |
| Projets | Recherche, statut, projet courant |
| Métré et Quantitatif | Chantier, recherche, statut, type d’espace, niveau |
| Devis | Chantier, recherche, statut, mode |
| Achats | Projet courant, projet précis ou tous les projets ; recherche, statut, lot, fournisseur et période de création |
| Planning | Chantier, recherche, statut, priorité, lot et échéance ; mêmes résultats en liste, Gantt et dépendances |
| Documents | Chantier, recherche, catégorie, liaison, type de fichier et période d’ajout |
| Chat | Conversation générale/chantier, recherche, type de contenu, tous les auteurs/mes messages |
| Rapports historiques | Chantier, recherche, module, statut, type et période, dont dates personnalisées |
| Analyse des rapports | Filtres avancés existants conservés et actualisation commune connectée |
| Utilisateurs | Recherche et rôle |
| Clients et Fournisseurs | Recherche et type Particulier/Entreprise |
| Taxes et TVA | Recherche et taux par défaut/autres taux |

Les filtres peuvent être combinés et réinitialisés. Les listes indiquent les résultats et distinguent une recherche sans résultat. Les formulaires de configuration ne reçoivent pas de filtres sans objet ; la barre d’actualisation y reste accessible.

Les raccourcis d’une fiche projet sélectionnent ce projet avant d’ouvrir sa destination. Le tableau de bord ouvre Planning/Rapports depuis ses lignes de statut ; ses métriques utilisent maintenant la table des tâches du planning et les échéances pour calculer les retards. Le Quantitatif défile sur les deux axes et ses totaux correspondent aux espaces filtrés.

La sélection fournit le contexte courant dans les paramètres ; les données d’entreprise (clients, fournisseurs et TVA) restent communes à l’entreprise. Les fiches d’édition restent attachées à l’entité ouverte. Dans le chat, la barre reste accessible avec le clavier en paysage ; la réinitialisation des filtres remonte alors dans l’en-tête pour laisser de la place aux messages et à la saisie.

**Validation locale :** `flutter analyze --no-pub` sans anomalie et **105 tests réussis**. Les tests couvrent les filtres, les changements de chantier, la conservation de saisie et de sélection pendant l’actualisation, les compteurs et les formats mobile/paysage. Un test par module vérifie la présence d’un unique sélecteur interactif, et un autre change le chantier depuis Planning puis vérifie sa conservation dans Quantitatif. Les tests emploient des dépôts ou transports simulés ; aucune donnée métier de production n’a été modifiée pour les vérifier.
