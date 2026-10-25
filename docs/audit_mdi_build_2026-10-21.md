**Audit de MDI Build — 21 octobre 2026**

Projet : `C:\mdi_build_premium_app` · Flutter · version déclarée `1.9.0+10`.

L’application possède déjà une couverture métier étendue et une identité visuelle reconnaissable. La priorité est de rendre les données et les parcours fiables : un écran soigné perd son utilité si une saisie devient zéro, si une fiche ouvre le mauvais chantier ou si un rapport présente des chiffres incomplets. Une refonte totale n’est pas nécessaire ; une stabilisation suivie d’une simplification visuelle serait plus utile.

**Périmètre et niveau de preuve**

Revue des sources des modules Connexion, Projets, Tableau de bord, Métré, Quantitatif, Devis, Achats, Planning, Documents, Chat, Rapports et Réglages ; des modèles, services, exports, tests, SQL et fonctions Supabase ; du workflow de déploiement.

- `flutter analyze --no-pub` : **aucune anomalie signalée**.
- `flutter test --no-pub --reporter expanded` : **69 tests existants réussis**.
- Cinq diagnostics locaux supplémentaires réussis : trois rendus, un scénario Quantitatif et un scénario de saisie Métré. Les deux derniers reproduisent des anomalies existantes ; leur réussite ne signifie pas que celles-ci ont été corrigées.
- Quatre captures examinées : connexion mobile, dashboard clair et sombre, quantitatif avec 30 espaces. Données fictives, rendu de test, dimensions et styles issus du thème de production ; **Segoe UI remplace Inter pour les captures hors ligne**. Ce ne sont pas des captures de la session personnelle de l’utilisateur.
- L’ouverture de la version installée n’a pas abouti. Aucun parcours connecté sur données réelles, aucune base de production ni politique RLS déployée n’a été inspecté. Les constats de sécurité SQL sont donc conditionnés au déploiement des fichiers examinés.
- Aucun code applicatif ni donnée métier n’a été modifié. Seuls le rapport, ses captures et des diagnostics dans `build/audit/` ont été créés. Les fichiers de secrets n’ont pas été consultés.

Priorités : **P1** = fiabilité/confidentialité à traiter avant d’élargir l’usage ; **P2** = stabilisation et efficacité quotidiennes ; **P3** = finition et confort. « Confirmé au code » ne signifie pas « reproduit sur la production ».

**Les décisions à prendre en premier**

| Priorité | Problème | Conséquence | Action proposée |
| --- | --- | --- | --- |
| P1 | Sauvegardes en plusieurs requêtes avec suppression des anciennes lignes | Devis/achat incomplet après un échec partiel | Sauvegarde atomique côté serveur et gestion des conflits |
| P1 | Nombres français non normalisés | `2,5` devient `0` | Validation commune des nombres et unités visibles |
| P1 | Contexte chantier implicite | Consultation ou rattachement au mauvais chantier | Porter le projet dans la navigation et les entités liées |
| P1 | Indicateurs et anciens rapports déconnectés des dépôts métier | Zéros silencieux et périodes trompeuses | Mutualiser données/calculs et afficher les erreurs |
| P1 | Accès et confidentialité insuffisamment garantis | Messages dits privés, notifications et sessions à risque | Contrôles serveur et tests avec plusieurs comptes/entreprises |
| P1 | Quantitatif sans défilement vertical | Dernières lignes inaccessibles | Tableau défilable sur les deux axes et adaptation mobile |
| P1/P2 | Contrastes faibles dans les palettes | Lecture difficile sur le terrain | Couleurs de contenu calculées depuis le fond réel |
| P2 | Parcours d’erreur, brouillons et exports incomplets | Travail perdu ou utilisateur bloqué | Réessai, conservation de saisie et enregistrement explicite |

**Visuel, ergonomie et accessibilité**

**V01 — P1 : corriger les contrastes avant d’ajouter des variantes graphiques.** Le bandeau Ardoise Nuit impose du texte blanc sur un dégradé jaune. Les ratios calculés varient d’environ **1,50:1 à 2,24:1** ; le sous-titre opérationnel est particulièrement concerné. La navigation Blueprint par défaut utilise des icônes bleues sur pétrole, environ **1,76:1**. Les accents jaunes/ocres personnalisables posent aussi problème avec les textes blancs des boutons : **1,87:1** et **2,94:1**. Le choix de la couleur de contenu dépend du mode clair/sombre, pas de la luminosité de l’accent. Prévoir des couples fond/texte validés et des couleurs neutres pour le texte courant. Le W3C donne comme repères 4,5:1 pour le texte courant et 3:1 pour le grand texte, avec les exceptions prévues par le critère. [Référence W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

Preuves : `lib/app/theme/app_theme.dart:26`, `lib/app/theme/app_palette_colors.dart:120`, `lib/shared/presentation/premium_ui.dart:162`, `lib/shared/presentation/main_shell_page.dart:328`. Voir [dashboard sombre](audit-assets-2026-10-21/dashboard_ardoiseNuit.png) et [dashboard clair](audit-assets-2026-10-21/dashboard_blueprintClair.png).

**V02 — P2 : alléger la navigation et la répétition des cartes.** Chaque entrée latérale cumule fond de carte, bordure, ombre et pastille d’icône. Les contenus ajoutent des bandeaux, cartes et sous-cartes similaires. Le filigrane central traverse également les zones de lecture et laisse apparaître le rectangle du bitmap dans le rendu clair. L’effet donne beaucoup de poids aux éléments secondaires. Conserver une barre latérale plus simple, un état actif évident et une seule action principale par écran. Réduire ombres, arrondis et contours répétitifs ; retirer le filigrane des tableaux/cartes de données et réserver l’accent aux actions et alertes utiles.

Preuves : `lib/shared/presentation/main_shell_page.dart:297`, `lib/shared/presentation/premium_ui.dart:6` et `:659`, `lib/features/documents/presentation/documents_page.dart:437` et `:560`.

**V03 — P2 : rendre le dashboard plus opérationnel et plus dense sur ordinateur.** Le rendu consacre beaucoup de hauteur à quatre compteurs disposés en grandes lignes. Regrouper les indicateurs secondaires dans une grille compacte. Remonter les informations qui demandent une action : tâches en retard, achats à valider, livraisons attendues, devis en attente, avec accès direct aux éléments concernés. Afficher clairement le périmètre « entreprise » ou « chantier » et la dernière actualisation.

Preuve : `lib/features/dashboard/presentation/dashboard_page.dart:40`. Les chiffres des captures sont fictifs ; cette recommandation porte sur la hiérarchie et l’espace occupé.

**V04 — P1/P2 : adapter réellement le Quantitatif aux petits écrans.** Le tableau est fixé à **1 820 px** et ne possède qu’un défilement horizontal. Le diagnostic à 1 440 × 1 000 avec 30 pièces confirme que « Pièce 30 » existe mais est hors de la zone accessible ; le seul axe de défilement ancêtre est horizontal. Ajouter le défilement vertical, une barre horizontale visible et une colonne de nom stable. Sur téléphone, proposer une fiche compacte par espace ou un tableau à colonnes sélectionnables. Ajouter les unités aux en-têtes et conserver les totaux accessibles.

Preuve : `lib/features/quantitatif/presentation/quantitatif_page.dart:235`. Voir [capture du quantitatif](audit-assets-2026-10-21/quantitatif_30_lignes.png).

**V05 — P2 : harmoniser le Gantt avec les thèmes.** Des fonds blancs sont imposés dans les cellules, même en thème sombre. Des statuts et libellés de barres utilisent une taille de 10. Employer les surfaces du thème, agrandir les informations de suivi et permettre l’ouverture du détail d’une tâche tronquée. Vérifier le nom des tâches pendant le déplacement de la chronologie.

Preuves : `lib/features/planning/presentation/gantt_view.dart:343`, `:362`, `:430`, `:541`. Constat au code ; rendu réel du Gantt non capturé pendant cet audit.

**V06 — P2 : aider à sortir des erreurs et des écrans vides.** Plusieurs pages présentent directement une exception technique ; le sélecteur de projet disparaît en cas d’échec. Standardiser les états : message compréhensible, Réessayer, conservation de la saisie et action adaptée à l’état vide (« Ajouter un premier espace », « Réinitialiser les filtres »). L’onglet Analyse des rapports possède déjà un meilleur parcours de réessai à réutiliser.

Preuves : `lib/features/dashboard/presentation/dashboard_page.dart:358`, `lib/shared/presentation/project_selector_card.dart:48`, `lib/features/projects/presentation/projects_page.dart:364`, `lib/features/reports/presentation/analysis/report_analysis_tab.dart:367`.

**V07 — P2/P3 : compléter l’accès clavier et lecteur d’écran.** Les cartes interactives reposent sur un `GestureDetector`, sans comportement clavier explicitement prévu. Les pastilles de couleur font 40 × 40 et n’annoncent pas explicitement leur sélection ; la navigation ne fournit pas clairement son état sélectionné. Utiliser des contrôles activables au clavier, un focus visible et des libellés/états sémantiques. Vérifier les écrans avec texte agrandi.

Preuves : `lib/shared/presentation/premium_ui.dart:87`, `lib/features/settings/presentation/appearance_settings_page.dart:263`, `lib/shared/presentation/main_shell_page.dart:291`.

**V08 — P3 : unifier le vocabulaire et améliorer la connexion.** Harmoniser « MD Build »/« MDI Build », « Dashboard »/« Tableau de bord », tutoiement/vouvoiement et dates françaises. Retirer les phrases décrivant la conception de l’interface. La connexion est déjà simple et défilable ; ajouter l’affichage temporaire du mot de passe, une validation des champs et une aide claire de récupération/assistance correspondant au fonctionnement réel des comptes.

Preuves : `lib/features/dashboard/presentation/dashboard_page.dart:40`, `lib/app/app.dart:108`, `lib/features/auth/presentation/login_page.dart:100`, `lib/features/projects/presentation/projects_page.dart:312`. Voir [connexion mobile](audit-assets-2026-10-21/login_mobile.png).

**Fonctionnel et intégrité des données**

**F01 — P1 : rendre les sauvegardes atomiques.** Devis et achats sauvegardent l’en-tête, suppriment toutes les anciennes lignes, puis insèrent les nouvelles par des appels séparés. Une erreur après la suppression laisse le document sans lignes ; deux utilisateurs peuvent écraser leurs modifications. Les rapports et leurs sections/sources présentent aussi des écritures successives non atomiques. Prévoir une transaction serveur par document, un résultat complet et un contrôle de version pour les éditions simultanées.

Preuves : `lib/features/devis/data/devis_repository.dart:65` et `:86`, `lib/features/achats/data/purchases_repository.dart:71`, `lib/features/reports/data/reports_repository.dart:76`, `lib/features/reports/services/report_generation_service.dart:111`. Séquence confirmée au code ; panne réseau non injectée sur une base réelle.

**F02 — P1 : accepter les nombres français et refuser les valeurs invalides.** Le diagnostic reproduit une longueur `2,5` transmise comme `0.0`. `double.tryParse(...) ?? 0` transforme aussi plusieurs budgets/prix erronés en zéro, et certaines quantités en un. Les noms vides et dimensions négatives ne sont pas correctement bloqués dans les formulaires concernés. Partager un parseur virgule/point, ajouter les contraintes métier et afficher l’erreur au champ. Afficher les unités (m, m², unité monétaire configurée) et un clavier numérique adapté.

Preuves : `lib/features/metrage/presentation/widgets/space_form.dart:75`, `lib/features/metrage/presentation/widgets/opening_form.dart:64`, `lib/features/projects/presentation/project_form_page.dart:86`, `lib/features/achats/presentation/widgets/purchase_form.dart:163`.

**F03 — P1 : ouvrir le chantier de la fiche utilisée.** Les boutons Planning, Rapports et Documents de chaque fiche projet naviguent vers une route générique sans sélectionner ce projet. Exemple : A est courant ; cliquer Planning sur B conserve A. Le bouton Achats ne porte pas non plus le contexte de la fiche et ouvre une liste multi-projets. Transmettre le projet explicitement et afficher le nom du chantier au point d’action ; une URL contenant le projet rendrait aussi les liens plus fiables.

Preuves : `lib/features/projects/presentation/projects_page.dart:475`, `lib/features/projects/presentation/providers/selected_project_provider.dart:42`.

**F04 — P1 : rattacher les documents au projet de l’achat.** Les achats peuvent appartenir à des projets différents du projet courant. Leur section Documents ne reçoit que l’achat ; le dialogue et le provider réutilisent ensuite le projet courant. Avec A courant et un achat de B, des documents peuvent être masqués, rejetés ou rattachés à A. Transmettre ensemble les identifiants achat/projet et vérifier leur cohérence côté serveur.

Preuves : `lib/features/achats/presentation/widgets/purchase_form.dart:338`, `lib/features/achats/presentation/purchase_documents_section.dart:23`, `lib/features/documents/presentation/providers/documents_providers.dart:54`, `lib/features/documents/presentation/document_form_dialog.dart:91` et `:155`.

**F05 — P1 : corriger les sources du tableau de bord.** Le planning lit/écrit `project_tasks`, mais les métriques cherchent `tasks` puis `planning_tasks`. Les erreurs sont absorbées et converties en liste vide. De plus, le compteur « en retard » cherche un mot dans le statut au lieu de comparer l’échéance et l’état d’achèvement. Les chiffres peuvent donc annoncer zéro ou manquer les retards. Réutiliser le dépôt Planning et une règle de retard commune. Afficher « indisponible » quand la requête échoue. Des vues de compatibilité de production pourraient atténuer le premier défaut ; aucune n’est livrée.

Preuves : `lib/features/planning/data/planning_repository.dart:15`, `lib/features/dashboard/services/dashboard_metrics_service.dart:27`, `:74` et `:210`.

**F06 — P1 : fiabiliser les rapports automatiques classiques.** La période choisie est imprimée mais n’est pas appliquée aux requêtes. Le générateur utilise également les mauvaises tables de tâches, filtre `projects.project_id` alors que la clé est `projects.id`, et additionne des champs de totaux/surfaces absents des modèles et du schéma fournis. Ces erreurs sont masquées par des valeurs vides/zéro. Les données de production pourraient contenir des colonnes ou vues supplémentaires ; le dépôt ne permet pas de l’établir. L’onglet **Analyse**, plus récent, filtre réellement les périodes et réutilise les lignes métier : prendre ce parcours comme base commune.

Preuves : `lib/features/reports/services/report_dashboard_generation_service.dart:207`, `:258`, `:399`, `:459` et `:507`, `lib/features/reports/analysis/report_analysis_repository.dart:97`. Ne pas généraliser le défaut de période à l’onglet Analyse ; son métré est explicitement présenté sans période.

**F07 — P1/P2 : définir l’effet des statuts sur les quantités.** Les espaces archivés/annulés restent chargés puis intégrés au Quantitatif et à l’import Devis. Clarifier les statuts qui contribuent au chiffrage et appliquer la même règle dans tous les modules, avec un accès séparé aux archives.

Preuves : `lib/features/metrage/data/spaces_repository.dart:11`, `lib/core/services/quantity_service.dart:5`, `lib/features/devis/presentation/devis_page.dart:274`.

**F08 — P2 : relier les taux de TVA aux devis.** Les réglages stockent des taux par entreprise, avec un taux par défaut, mais l’écran Devis, le PDF et l’Analyse appliquent tous 19 % en dur. Changer les réglages ne change donc pas les devis. Lire le taux paramétré à la création et le conserver dans chaque document pour préserver son historique. Ce constat porte sur l’intégration, pas sur la conformité juridique du taux de 19 %.

Preuves : `lib/features/devis/presentation/devis_page.dart:894`, `lib/features/devis/services/quote_pdf_service.dart:36`, `lib/features/reports/analysis/report_analysis.dart:179`, `lib/features/settings/presentation/tax_rate_form_dialog.dart:66`.

**F09 — P2 : préserver les données lors des réouvertures.** Une quantité de devis stockée avec trois décimales est convertie en texte à deux décimales à l’édition : `1,234` devient `1,23` à la sauvegarde. Dans les achats, le fournisseur propre à une ligne n’est pas recopié dans le brouillon et disparaît lors de la reconstruction. Conserver la précision d’origine et tous les champs du modèle, même ceux qui ne sont pas modifiés visuellement.

Preuves : `lib/features/devis/presentation/devis_page.dart:1691`, `supabase/2026_project_quote_items.sql:5`, `lib/features/achats/presentation/widgets/purchase_form.dart:84` et `:155`, `lib/core/models/purchase_item.dart:35`.

**F10 — P2 : donner un vrai cycle de vie aux devis et validations.** Un devis est marqué « envoyé » avant la génération et le partage ; annuler le partage laisse ce statut. Un devis signé reste modifiable en conservant sa signature. Les achats restent éditables après validation/commande/livraison. Distinguer préparation, export et envoi confirmé ; figer une version signée ; créer une révision pour les changements et réinitialiser la validation quand les montants changent.

Preuves : `lib/features/devis/presentation/devis_page.dart:709`, `:181` et `:912`, `lib/features/achats/presentation/achats_page.dart:635`.

**F11 — P2 : conserver le travail en cas d’erreur ou de navigation.** Les formulaires Espace/Ouverture passent en enregistrement sans `catch/finally` ; un échec peut laisser le bouton bloqué. Les formulaires examinés n’ont pas de garde de sortie ni de brouillon local. Le devis n’a pas de verrou global empêchant plusieurs créations rapides avant réception du premier résultat. Ajouter erreurs réessayables, brouillons, confirmation des modifications non enregistrées et blocage des doubles soumissions.

Preuves : `lib/features/metrage/presentation/widgets/space_form.dart:68`, `lib/features/metrage/presentation/widgets/opening_form.dart:58`, `lib/features/devis/presentation/devis_page.dart:160`.

**F12 — P2 : terminer le parcours d’export Excel classique.** Le fichier est écrit dans un répertoire temporaire, puis seul son chemin est affiché. Sur mobile cela aide peu ; sur le web ce chemin utilise `path_provider`/`dart:io` sans implémentation de téléchargement. Réutiliser l’enregistrement explicite par octets déjà présent dans l’Analyse et proposer enregistrer/ouvrir/partager selon la plateforme. Les PDF ne sont pas concernés par ce constat.

Preuves : `lib/features/reports/services/report_export_service.dart:206`, `lib/features/reports/presentation/reports_page.dart:303`, `lib/features/reports/analysis/report_analysis_export.dart:665`.

**F13 — P2 : rendre les documents récupérables sous panne.** La suppression du fichier et celle de la fiche sont séparées ; l’une peut réussir sans l’autre. Les URL signées sont générées pour une heure et le bouton de rafraîchissement réutilise l’URL déjà obtenue. Prévoir une suppression suivie/reprenable et régénérer un lien expiré.

Preuves : `lib/features/documents/data/documents_repository.dart:205` et `:219`, `lib/features/documents/presentation/document_view_page.dart:28` et `:141`.

**F14 — P2 : préciser les règles de métré et de planning.** Tous les types d’espace utilisent les formules d’une pièce rectangulaire, même façade/toiture/fondation/clôture. La quantité multiplie les murs mais pas les ouvertures : préciser si celles-ci sont saisies par exemplaire ou au total. Le planning stocke des dépendances sans détection de cycle ni recalcul de dates. Ces comportements demandent une décision métier, puis une aide visible dans les formulaires.

Preuves : `lib/core/models/space_item.dart:34`, `lib/core/enums/space_type.dart:1`, `lib/features/planning/data/planning_repository.dart:58`.

**F15 — P2 : actualiser les vues dérivées et éviter les doublons d’import.** Le dashboard n’est pas invalidé par les mutations des autres modules. Chaque import Métré → Devis ajoute de nouveau les lignes sans reconnaître leur provenance. Invalider les agrégats après mutation et proposer un aperçu avec choix ajouter/actualiser/remplacer.

Preuves : `lib/features/dashboard/presentation/providers/dashboard_providers.dart:13`, `lib/features/dashboard/presentation/dashboard_page.dart:33`, `lib/features/devis/presentation/devis_page.dart:289`.

**Sécurité, droits et sessions**

**S01 — P1 : réinitialiser les caches au changement de compte.** Le profil et les projets sont des providers persistants sans dépendance à la session. La déconnexion appelle `signOut()` mais ne remet pas ces caches à zéro ; le `ProviderScope` global subsiste. Sur un appareil partagé, risque de réafficher les données en mémoire du compte précédent et de réutiliser son contexte. Le routeur protège bien les pages sans session ; cette protection ne purge pas la mémoire. Faire dépendre les données de l’identité et isoler aussi les préférences projet/non-lus par utilisateur.

Preuves : `lib/features/projects/presentation/providers/current_profile_provider.dart:7`, `lib/features/projects/presentation/providers/projects_providers.dart:10`, `lib/shared/presentation/main_shell_page.dart:65`, `lib/main.dart:48`, `lib/core/services/project_selection_storage.dart:4`. Scénario avec deux comptes non exécuté.

**S02 — P1 : contrôler l’entreprise dans `notify-event`.** La fonction authentifie l’appelant puis accepte `companyId`, destinataire et contenu du client. Elle recherche les destinataires avec le client privilégié sans vérifier l’appartenance de l’appelant. Si cette version est déployée, un compte connecté connaissant un identifiant d’entreprise peut lui adresser des notifications arbitraires. Dériver l’entreprise/l’auteur côté serveur, vérifier l’événement et le destinataire, limiter le débit et éviter les doublons.

Preuve : `supabase/functions/notify-event/index.ts:39`, `:47` et `:60`. Défaut de contrôle confirmé dans la fonction locale, sans tentative d’exploitation.

**S03 — P1 : vérifier la confidentialité des messages annoncés privés.** L’interface propose « Message privé » et un cadenas ; les flux et l’affichage ne filtrent pas les participants. La confidentialité dépend donc entièrement de la lecture autorisée par le serveur. Aucune politique SELECT complète du chat n’est versionnée ; un commentaire évoque une isolation par entreprise. **Une fuite en production n’est pas établie**, mais si le serveur retourne un message destiné à un tiers, l’interface l’affiche. Tester trois utilisateurs, la recherche, les non-lus, les pièces jointes et les flux temps réel ; imposer les participants dans la RLS.

Preuves : `lib/features/chat/presentation/chat_page.dart:659`, `:994` et `:1121`, `lib/features/chat/data/chat_repository.dart:22`, `supabase/2026_chat_general_channel.sql:9`.

**S04 — P1 : limiter les colonnes modifiables d’un message.** Le SQL autorise UPDATE pour l’expéditeur ou le destinataire sur toute la ligne. Cela ne limite pas le destinataire au reçu de lecture, contrairement au commentaire. Si déployé et sans autre protection, il peut modifier le contenu reçu via API. Prévoir une opération dédiée pour les accusés de lecture et réserver l’édition de contenu à l’auteur.

Preuve : `supabase/2026_chat_read_receipts_and_edit.sql:13`. La RLS contrôle les lignes ; la restriction de colonnes/actions doit être traitée explicitement. [Documentation Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

**S05 — P1 : restreindre l’écriture des logos par entreprise.** La politique locale `company_logo_write` vérifie uniquement le bucket et l’authentification. Si elle est déployée ainsi, un utilisateur connecté peut écraser/supprimer le logo d’une autre entreprise. Restreindre le préfixe du chemin et le rôle autorisé, y compris pour l’upsert et la suppression.

Preuves : `supabase/schema.sql:281`, `lib/features/settings/data/company_repository.dart:45`. [Contrôle d’accès Storage](https://supabase.com/docs/guides/storage/security/access-control).

**S06 — P1/P2 : faire appliquer les autorisations métier au serveur.** Le passage d’un achat à « DG validé » n’est pas limité au directeur dans l’interface, et le dépôt accepte le statut/auteur transmis. Les règles serveur des achats ne sont pas fournies : leur protection effective reste à vérifier. Définir une matrice directeur/chef de projet/autres rôles, contrôler chaque transition côté serveur et garder l’historique. Masquer un bouton ne suffit pas à protéger une opération.

Preuves : `lib/features/achats/presentation/achats_page.dart:634`, `lib/features/achats/data/purchases_repository.dart:105`.

**S07 — P2 : rendre l’administration des utilisateurs effective et vérifiable.** `is_active` existe mais n’est pas utilisé par les contrôles audités. Un changement de rôle peut afficher un succès sans vérifier qu’une ligne a été modifiée. Vérifier les résultats, protéger le dernier directeur et définir une désactivation réelle avec révocation adaptée des sessions et contrôle des opérations sensibles.

Preuves : `supabase/schema.sql:22`, `lib/features/projects/presentation/providers/current_profile_provider.dart:19`, `supabase/functions/admin-users/index.ts:55`, `lib/features/settings/data/settings_repository.dart:34`, `lib/features/settings/presentation/settings_page.dart:70`.

**S08 — P2 : contraindre les rattachements inter-entreprises.** Dans le schéma fourni, entreprise et identifiant de projet sont des clés indépendantes ; certaines policies vérifient seulement l’entreprise de la ligne. Des rattachements incohérents deviennent possibles avec un identifiant connu. Ajouter des contraintes ou vérifications communes qui garantissent que projet, achat, espace et document appartiennent au même contexte.

Preuves : `supabase/schema.sql:39` et `:127`, `supabase/2026_client_supplier_links.sql:5`. Contraintes et règles supplémentaires de production non vérifiées.

**Architecture, performance et exploitation**

**T01 — P1/P2 : versionner une base complète et reproductible.** Le schéma reconnaît qu’il n’est pas synchronisé avec la base réelle. Plusieurs tables majeures, buckets et politiques utilisés par le client n’ont pas de création complète versionnée. Le guide demande pourtant d’exécuter uniquement `schema.sql`. Produire une baseline sans données, des migrations ordonnées, un environnement de test et des tests RLS. Cette lacune limite aussi la portée de cet audit ; elle ne prouve pas que la production est permissive.

Preuves : `supabase/schema.sql:183`, `docs/setup.md:7`.

**T02 — P2 : partager les mêmes calculs entre écrans, rapports et PDF.** Les divergences de tables, surfaces, périodes et totaux viennent de calculs/requêtes dupliqués. Faire consommer aux écrans, exports et agrégats les mêmes modèles et services. L’Analyse des rapports constitue une meilleure base que les anciens générateurs à noms de tables alternatifs et erreurs absorbées.

Preuves : `lib/features/dashboard/services/dashboard_metrics_service.dart:27`, `lib/features/reports/services/report_dashboard_generation_service.dart:507`, `lib/features/reports/analysis/report_analysis_repository.dart:97`.

**T03 — P2 : éviter les requêtes par ligne et prévoir les gros volumes.** La liste Achats utilise un `FutureBuilder` par achat pour calculer son total, relancé à la reconstruction. Les erreurs ne sont pas traitées explicitement. Plusieurs listes chargent l’ensemble des données sans pagination ; le chat charge l’historique complet du périmètre. Grouper les lignes/totaux, stabiliser les providers, paginer listes et messages, puis mesurer avec un jeu de données représentatif. L’Analyse possède déjà une pagination à réutiliser.

Preuves : `lib/features/achats/presentation/achats_page.dart:549` et `:621`, `lib/features/documents/data/documents_repository.dart:20`, `lib/features/chat/data/chat_repository.dart:22`, `lib/features/reports/analysis/report_analysis_repository.dart:58`. Aucune mesure de latence de production réalisée.

**T04 — P2 : ne pas supprimer les tokens lors d’une panne temporaire de notifications.** `sendToToken` retourne faux sur toute erreur HTTP et les appelants suppriment le token. Une erreur transitoire peut donc désinscrire un appareil valide. Distinguer token invalide et incident réessayable ; prévoir une reprise progressive et écouter la rotation du token.

Preuves : `supabase/functions/_shared/fcm.ts:127`, `supabase/functions/notify-event/index.ts:125`, `supabase/functions/send-push/index.ts:68`, `supabase/functions/check-task-deadlines/index.ts:99`. Aucun abonnement `onTokenRefresh` trouvé.

**T05 — P2 : protéger le démarrage et rendre les incidents diagnostiquables.** Firebase et Supabase sont initialisés avant `runApp` sans écran de récupération. Une erreur d’initialisation peut empêcher toute interface d’apparaître. Prévoir un écran explicite de configuration/connexion indisponible, un réessai et des journaux structurés sans secrets. Les push sont volontairement limités à Android/iOS ; la présence d’une cible Windows ne permet pas d’affirmer un crash Firebase Windows. Linux est explicitement non configuré dans les options Firebase.

Preuves : `lib/main.dart:22`, `lib/firebase_options.dart:29`. Aucun dispositif Sentry/Crashlytics trouvé dans les sources auditées ; le choix d’un outil de suivi reste une décision de produit.

**T06 — P2 : compléter les tests sur les risques réels.** Les 69 tests passent, mais plusieurs tests responsive utilisent un thème simplifié sans `AppTheme.build`. Ils ne garantissent ni les contrastes, ni toutes les dimensions de production, ni les transactions/RLS. Ajouter des tests sur changements de compte, isolation d’entreprise, sauvegarde interrompue, contextes projet, virgules, précision, périodes, droits et gros tableaux. Prévoir les polices de test explicitement : le premier essai de capture avec Google Fonts a échoué car le binding de tests bloque ses requêtes HTTP ; le rendu final utilise une police locale déclarée.

Preuves : `test/ui/responsive_and_chat_test.dart:28`, diagnostics temporaires `build/audit/audit_visual_test.dart`. Le workflow existant lance déjà analyse et tests avant le build : `.github/workflows/deploy.yml`.

**Ordre de réalisation conseillé**

1. **Fiabilité et accès.** Sauvegardes atomiques ; parseur/validation des nombres ; propagation du projet ; purge des caches à la session ; contrôle `notify-event` ; vérification des règles chat/Storage/approbation avec des comptes de test ; accès aux dernières lignes du Quantitatif.
2. **Cohérence métier.** Unifier dashboard/rapports/calculs ; appliquer réellement les périodes ; relier les taux ; préserver la précision ; verrouiller les versions signées et les validations ; reprendre les erreurs et exports.
3. **Présentation et confort.** Réduire l’empilement de cartes et la hauteur des compteurs ; sécuriser les contrastes de toutes les palettes ; améliorer tableaux/Gantt mobile ; ajouter clavier, sémantique, brouillons et vocabulaire homogène.

L’effort exact dépend de la base réellement déployée et des règles métier retenues. Une estimation en jours avant cette vérification serait fragile.

**Critères de validation à utiliser pour la suite**

| Scénario | Résultat attendu |
| --- | --- |
| Deux comptes se succèdent sur le même appareil | Aucune donnée, sélection ni compteur du premier compte dans le second |
| Trois utilisateurs, dont un tiers à une conversation privée | Le tiers ne peut ni lire ni télécharger les messages/fichiers privés via interface, API ou flux temps réel |
| Deux entreprises et plusieurs rôles | Aucun accès croisé ni validation réservée réalisable par un rôle non autorisé |
| Réseau interrompu pendant la sauvegarde d’un devis/achat | Ancienne version conservée ou nouvelle version complète, jamais un document partiellement vidé |
| `2,5`, `2.5`, valeur vide, négative et non numérique | Décimales cohérentes et erreurs explicites, sans conversion silencieuse |
| Chantier A courant, action depuis la fiche/achat B | Destination et documents rattachés à B |
| Deux périodes distinctes de rapport | Données réellement filtrées ; mêmes résultats dans écran, synthèse, PDF et Excel |
| 30 puis plusieurs centaines d’espaces/messages/documents | Dernière ligne accessible, chargement maîtrisé et totaux complets |
| Réouverture/sauvegarde d’un devis sans changement | Quantités, fournisseurs, taux et montants identiques |
| Export web, Android/iOS et Windows | Fichier récupérable par un parcours adapté à chaque plateforme |
| Téléphone 360/390 px, paysage avec clavier, tablette, bureau et texte à 200 % | Actions, champs, tableaux et focus accessibles sans perte de saisie |
| Toutes les palettes et accents proposés | Contrastes contrôlés, texte lisible et information non portée par la couleur seule |

**Ce qu’il faut conserver**

La séparation par modules, les composants partagés, la navigation adaptative, les boutons principaux de 48 px, les confirmations de suppression déjà présentes et la conservation du contenu lors de la rotation constituent une bonne base. L’Analyse des rapports est plus aboutie dans la cohérence de ses données et de ses exports. Il serait utile de généraliser ces mécanismes aux parcours plus anciens tout en conservant l’identité pétrole/or de MDI Build.
