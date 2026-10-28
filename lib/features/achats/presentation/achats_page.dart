import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/notify_event_service.dart';
import '../../../core/services/pdf_letterhead.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_scaffold_title.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/projects_providers.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../../settings/presentation/providers/company_providers.dart';
import '../../settings/presentation/providers/suppliers_providers.dart';
import '../services/purchase_pdf_service.dart';
import 'providers/purchases_providers.dart';
import 'widgets/purchase_form.dart';
import '../../../shared/presentation/party_pickers.dart';
import '../../../core/models/purchase_workflow.dart';
import 'purchase_documents_section.dart';
import '../../../shared/presentation/signature_icon.dart';
import 'purchase_tracking.dart';
import '../../projects/presentation/providers/project_scope_provider.dart';

class AchatsPage extends ConsumerStatefulWidget {
  const AchatsPage({super.key});

  @override
  ConsumerState<AchatsPage> createState() => _AchatsPageState();
}

class _AchatsPageState extends ConsumerState<AchatsPage> {
  final TextEditingController searchController = TextEditingController();
  String statusFilter = 'tous';
  String projectFilter = 'current';
  String lotFilter = 'tous';
  String supplierFilter = 'tous';
  String periodFilter = 'toutes';

  void _resetFilters() {
    setState(() {
      searchController.clear();
      statusFilter = 'tous';
      projectFilter = 'current';
      lotFilter = 'tous';
      supplierFilter = 'tous';
      periodFilter = 'toutes';
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final projects = await ref.read(projectsProvider.future);
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (profile == null || authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return;
    }

    final projectOptions = projects
        .map(
          (project) => DropdownMenuItem<String>(
            value: project.id,
            child: Text(project.name),
          ),
        )
        .toList();

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nouvel achat'),
          content: SizedBox(
            width: 760,
            child: PurchaseForm(
              projectOptions: projectOptions,
              onSubmit: (value) async {
                final purchase = Purchase(
                  id: '',
                  companyId: profile.companyId,
                  projectId: value.projectId,
                  title: value.title,
                  lot: value.lot,
                  notes: value.notes,
                  supplierId: value.supplierId,
                  status: 'brouillon',
                  requestedBy: authUser.id,
                  approvedBy: null,
                  orderedBy: null,
                  deliveredBy: null,
                  cancelledBy: null,
                  archivedBy: null,
                  approvedAt: null,
                  orderedAt: null,
                  deliveredAt: null,
                  cancelledAt: null,
                  archivedAt: null,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref.read(purchasesRepositoryProvider).createPurchase(
                      purchase,
                      value.items,
                    );

                ref.invalidate(activePurchasesProvider);
                ref.invalidate(archivedPurchasesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditDialog(
    BuildContext context, {
    required Purchase purchase,
  }) async {
    final projects = await ref.read(projectsProvider.future);
    final items = await ref
        .read(purchasesRepositoryProvider)
        .fetchPurchaseItems(purchase.id);

    final projectOptions = projects
        .map(
          (project) => DropdownMenuItem<String>(
            value: project.id,
            child: Text(project.name),
          ),
        )
        .toList();

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifier achat'),
          content: SizedBox(
            width: 760,
            child: PurchaseForm(
              projectOptions: projectOptions,
              initialPurchase: purchase,
              initialItems: items,
              onSubmit: (value) async {
                final updated = purchase.copyWith(
                  projectId: value.projectId,
                  title: value.title,
                  lot: value.lot,
                  notes: value.notes,
                  supplierId: value.supplierId,
                );

                await ref.read(purchasesRepositoryProvider).updatePurchase(
                      updated,
                      value.items,
                    );

                ref.invalidate(activePurchasesProvider);
                ref.invalidate(archivedPurchasesProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _printPurchase(
    BuildContext context, {
    required Purchase purchase,
    required String projectName,
  }) async {
    try {
      final items = await ref
          .read(purchasesRepositoryProvider)
          .fetchPurchaseItems(purchase.id);
      final company = await ref.read(currentCompanyProvider.future);
      final logoBytes = await PdfLetterhead.fetchLogoBytes(company);
      final suppliers = await ref.read(activeSuppliersProvider.future);
      final supplier =
          suppliers.where((s) => s.id == purchase.supplierId).firstOrNull;

      await PurchasePdfService().printPurchase(
        supplier: supplier,
        purchase: purchase,
        projectName: projectName,
        items: items,
        company: company,
        logoBytes: logoBytes,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur PDF : $error')),
        );
      }
    }
  }

  Future<void> _changeStatus(
    BuildContext context, {
    required Purchase purchase,
    required String status,
  }) async {
    final authUser = SupabaseService.client.auth.currentUser;

    try {
      await ref.read(purchasesRepositoryProvider).updatePurchaseStatus(
            purchaseId: purchase.id,
            status: status,
            actorId: authUser?.id,
            previousStatus: purchase.status,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$error'.contains('en_traitement')
              ? 'Étape « En traitement » non activée : passe le script SQL v2.1.'
              : 'Changement d’étape impossible : $error'),
        ));
      }
      return;
    }
    ref.invalidate(purchaseEventsProvider(purchase.id));

    ref.invalidate(activePurchasesProvider);
    ref.invalidate(archivedPurchasesProvider);

    await NotifyEventService.send(
      companyId: purchase.companyId,
      projectId: purchase.projectId,
      module: 'achats',
      title: 'Achat : ${_statusLabel(status)}',
      body: purchase.title,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : ${_statusLabel(status)}')),
      );
    }
  }

  Future<bool> _deletePurchase(
    BuildContext context, {
    required Purchase purchase,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer achat'),
        content: Text('Supprimer "${purchase.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: PremiumButtonStyles.destructive(context),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    await ref.read(purchasesRepositoryProvider).deletePurchase(purchase.id);

    ref.invalidate(activePurchasesProvider);
    ref.invalidate(archivedPurchasesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Achat supprimé.')),
      );
    }
    return true;
  }

  List<Purchase> _applyFilters(
    List<Purchase> purchases,
    Map<String, String> projectNamesById, {
    String? currentProjectId,
    Map<String, String> supplierNamesById = const {},
  }) {
    final query = searchController.text.trim().toLowerCase();

    return purchases.where((purchase) {
      final projectName =
          (projectNamesById[purchase.projectId] ?? purchase.projectId)
              .toLowerCase();

      final matchesStatus =
          statusFilter == 'tous' || purchase.status == statusFilter;
      final matchesSearch = query.isEmpty ||
          purchase.title.toLowerCase().contains(query) ||
          purchase.lot.toLowerCase().contains(query) ||
          projectName.contains(query) ||
          purchase.notes.toLowerCase().contains(query) ||
          (supplierNamesById[purchase.supplierId] ?? '')
              .toLowerCase()
              .contains(query);
      final projectId =
          projectFilter == 'current' ? currentProjectId : projectFilter;
      // « Projet courant » en vue « Tous les projets » : tous les achats.
      final matchesProject = projectFilter == 'all' ||
          (projectFilter == 'current' && projectId == null) ||
          purchase.projectId == projectId;
      final matchesLot = lotFilter == 'tous' || purchase.lot == lotFilter;
      final matchesSupplier = supplierFilter == 'tous' ||
          (supplierFilter == 'sans'
              ? purchase.supplierId == null
              : purchase.supplierId == supplierFilter);
      final today = DateUtils.dateOnly(DateTime.now());
      final created = DateUtils.dateOnly(purchase.createdAt);
      final matchesPeriod = switch (periodFilter) {
        'semaine' => !created.isAfter(today) &&
            !created.isBefore(today.subtract(const Duration(days: 6))),
        'mois' => !created.isAfter(today) &&
            !created.isBefore(today.subtract(const Duration(days: 29))),
        'mois_courant' =>
          created.year == today.year && created.month == today.month,
        _ => true,
      };

      return matchesStatus &&
          matchesSearch &&
          matchesProject &&
          matchesLot &&
          matchesSupplier &&
          matchesPeriod;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activePurchasesAsync = ref.watch(activePurchasesProvider);
    final archivedPurchasesAsync = ref.watch(archivedPurchasesProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final selectedProject = ref.watch(selectedProjectProvider).value;
    final scopeAll = ref.watch(projectScopeAllProvider);
    final suppliers = ref.watch(activeSuppliersProvider).value ?? const [];
    final supplierNames = <String, String>{
      for (final supplier in suppliers) supplier.id: supplier.name
    };
    final allPurchases = <Purchase>[
      ...?activePurchasesAsync.value,
      ...?archivedPurchasesAsync.value,
    ];
    final projectNames = <String, String>{
      for (final project in projectsAsync.value ?? const [])
        project.id: project.name,
    };
    final lots = {
      for (final purchase in allPurchases)
        if (purchase.lot.isNotEmpty) purchase.lot,
      if (lotFilter != 'tous') lotFilter,
    }.toList()
      ..sort();
    final supplierIds = <String>{
      ...supplierNames.keys,
      for (final purchase in allPurchases)
        if (purchase.supplierId != null) purchase.supplierId!,
      if (supplierFilter != 'tous' && supplierFilter != 'sans') supplierFilter,
    };
    final filtered = _applyFilters(allPurchases, projectNames,
        currentProjectId: scopeAll ? null : selectedProject?.id,
        supplierNamesById: supplierNames);

    // En-tête (titre + filtres) placé en tête de la liste : toute la page
    // défile d'un seul bloc.
    final header = <Widget>[
      AppScaffoldTitle(
        title: 'Achats',
        subtitle: 'Achats libres ou reliés au quantitatif et au devis.',
        action: ElevatedButton.icon(
          onPressed: () => _openCreateDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Nouvel achat'),
        ),
      ),
      const SizedBox(height: 16),
      ModuleFilterBar(
        collapsibleOnPhone: true,
        searchQuery: searchController.text,
        onSearchChanged: (value) =>
            setState(() => searchController.text = value),
        searchHint: 'Titre, lot, projet, fournisseur, remarque',
        onReset: _resetFilters,
        resultLabel:
            '${filtered.length} achat(s) sur ${allPurchases.length} · en cours et archives',
        filters: [
          ModuleFilterDropdown<String>(
            label: 'Projet',
            value: projectFilter,
            items: [
              DropdownMenuItem(
                  value: 'current',
                  child: Text(scopeAll
                      ? 'Projet de la barre : tous les projets'
                      : 'Projet courant : ${selectedProject?.name ?? "aucun"}')),
              const DropdownMenuItem(
                  value: 'all', child: Text('Tous les projets')),
              for (final project in projectsAsync.value ?? const [])
                DropdownMenuItem(value: project.id, child: Text(project.name)),
              if (projectFilter != 'current' &&
                  projectFilter != 'all' &&
                  !projectNames.containsKey(projectFilter))
                DropdownMenuItem(
                    value: projectFilter,
                    child: const Text('Projet indisponible')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => projectFilter = value);
              }
            },
          ),
          ModuleFilterDropdown<String>(
            label: 'Statut',
            value: statusFilter,
            items: [
              const DropdownMenuItem(value: 'tous', child: Text('Tous')),
              for (final status in PurchaseWorkflow.statuses)
                DropdownMenuItem(
                    value: status, child: Text(PurchaseWorkflow.label(status))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => statusFilter = value);
              }
            },
          ),
          ModuleFilterDropdown<String>(
            label: 'Lot',
            value: lotFilter,
            items: [
              const DropdownMenuItem(
                  value: 'tous', child: Text('Tous les lots')),
              for (final lot in lots)
                DropdownMenuItem(value: lot, child: Text(lot)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => lotFilter = value);
              }
            },
          ),
          ModuleFilterDropdown<String>(
            label: 'Fournisseur',
            value: supplierFilter,
            items: [
              const DropdownMenuItem(
                  value: 'tous', child: Text('Tous les fournisseurs')),
              const DropdownMenuItem(
                  value: 'sans', child: Text('Sans fournisseur')),
              for (final id in supplierIds)
                DropdownMenuItem(
                    value: id,
                    child:
                        Text(supplierNames[id] ?? 'Fournisseur indisponible')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => supplierFilter = value);
              }
            },
          ),
          ModuleFilterDropdown<String>(
            label: 'Création',
            value: periodFilter,
            items: const [
              DropdownMenuItem(
                  value: 'toutes', child: Text('Toutes les dates')),
              DropdownMenuItem(
                  value: 'semaine', child: Text('7 derniers jours')),
              DropdownMenuItem(value: 'mois', child: Text('30 derniers jours')),
              DropdownMenuItem(value: 'mois_courant', child: Text('Ce mois')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => periodFilter = value);
              }
            },
          ),
        ],
      ),
    ];

    return DefaultTabController(
      length: 2,
      child: ProjectModuleScaffold(
        appBar: AppBar(
          title: const Text('Achats'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En cours'),
              Tab(text: 'Archivés'),
            ],
          ),
        ),
        body: projectsAsync.when(
          skipError: true,
          data: (projects) {
            final projectNamesById = {
              for (final project in projects) project.id: project.name,
            };

            return TabBarView(
              // Changement d'onglet par les onglets seulement : un geste un
              // peu oblique ne fait plus basculer la liste.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                activePurchasesAsync.when(
                  // Une erreur passagère pendant une actualisation garde la
                  // liste affichée (et la position de défilement).
                  skipError: true,
                  data: (purchases) => _PurchasesList(
                    storageKey: 'achats-en-cours',
                    header: header,
                    purchases: _applyFilters(purchases, projectNamesById,
                        currentProjectId: scopeAll ? null : selectedProject?.id,
                        supplierNamesById: supplierNames),
                    projectNamesById: projectNamesById,
                    onEdit: (purchase) => _openEditDialog(
                      context,
                      purchase: purchase,
                    ),
                    onDelete: (purchase) => _deletePurchase(
                      context,
                      purchase: purchase,
                    ),
                    onPrint: (purchase, projectName) => _printPurchase(
                      context,
                      purchase: purchase,
                      projectName: projectName,
                    ),
                    onChangeStatus: (purchase, status) => _changeStatus(
                      context,
                      purchase: purchase,
                      status: status,
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur: $error')),
                ),
                archivedPurchasesAsync.when(
                  skipError: true,
                  data: (purchases) => _PurchasesList(
                    storageKey: 'achats-archives',
                    header: header,
                    purchases: _applyFilters(purchases, projectNamesById,
                        currentProjectId: scopeAll ? null : selectedProject?.id,
                        supplierNamesById: supplierNames),
                    projectNamesById: projectNamesById,
                    onEdit: (purchase) => _openEditDialog(
                      context,
                      purchase: purchase,
                    ),
                    onDelete: (purchase) => _deletePurchase(
                      context,
                      purchase: purchase,
                    ),
                    onPrint: (purchase, projectName) => _printPurchase(
                      context,
                      purchase: purchase,
                      projectName: projectName,
                    ),
                    onChangeStatus: (purchase, status) => _changeStatus(
                      context,
                      purchase: purchase,
                      status: status,
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erreur: $error')),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur projets: $error')),
        ),
      ),
    );
  }
}

class _PurchasesList extends ConsumerWidget {
  const _PurchasesList({
    required this.storageKey,
    required this.header,
    required this.purchases,
    required this.projectNamesById,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onChangeStatus,
  });

  /// Position de défilement mémorisée (retour de fiche, actualisation).
  final String storageKey;
  final List<Widget> header;
  final List<Purchase> purchases;
  final Map<String, String> projectNamesById;
  final Future<void> Function(Purchase purchase) onEdit;
  final Future<bool> Function(Purchase purchase) onDelete;
  final Future<void> Function(Purchase purchase, String projectName) onPrint;
  final Future<void> Function(Purchase purchase, String status) onChangeStatus;

  void _open(BuildContext context, Purchase purchase) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _PurchaseDetailPage(
        purchaseId: purchase.id,
        initial: purchase,
        projectNamesById: projectNamesById,
        onEdit: onEdit,
        onDelete: onDelete,
        onPrint: onPrint,
        onChangeStatus: onChangeStatus,
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: PageStorageKey<String>(storageKey),
      padding: const EdgeInsets.all(20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ...header,
        const SizedBox(height: 16),
        if (purchases.isEmpty)
          const PremiumSurfaceCard(
            child: Center(
              child: Text(
                  'Aucun achat ne correspond aux filtres. Réinitialisez-les ou changez de projet.'),
            ),
          )
        else
          for (final purchase in purchases)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PurchaseCard(
                key: ValueKey(purchase.id),
                purchase: purchase,
                projectName:
                    projectNamesById[purchase.projectId] ?? purchase.projectId,
                onOpen: () => _open(context, purchase),
              ),
            ),
      ],
    );
  }
}

/// Résumé d'un achat dans la liste. Un appui ouvre la fiche en plein écran ;
/// la couleur de l'étape n'apparaît que sur le cadre.
class _PurchaseCard extends ConsumerWidget {
  const _PurchaseCard({
    super.key,
    required this.purchase,
    required this.projectName,
    required this.onOpen,
  });

  final Purchase purchase;
  final String projectName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierName = (ref.watch(activeSuppliersProvider).value ?? const [])
        .where((s) => s.id == purchase.supplierId)
        .map((s) => s.name)
        .firstOrNull;
    final items = ref.watch(purchaseItemsProvider(purchase.id)).value;
    final total = items?.fold<double>(0, (sum, item) => sum + item.total);
    final color = _statusColor(purchase.status);
    final dateText = DateFormat('dd/MM/yyyy').format(purchase.createdAt);

    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          purchase.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                      ),
                      Text(
                        total == null
                            ? '… DA'
                            : '${total.toStringAsFixed(2)} DA',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(status: purchase.status),
                        if (purchase.orderNumber != null)
                          _InfoBadge(
                            icon: Icons.receipt_outlined,
                            label: purchase.orderNumber!,
                          ),
                        _InfoBadge(
                            icon: Icons.apartment_outlined, label: projectName),
                        if (supplierName != null)
                          _InfoBadge(
                            icon: Icons.local_shipping_outlined,
                            label: supplierName,
                          ),
                        _InfoBadge(
                            icon: Icons.calendar_today_outlined,
                            label: dateText),
                        PurchaseAttachButton(purchase: purchase),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fiche d'un achat en plein écran, défilable d'un seul bloc. Elle suit
/// les mises à jour (étape, pièces jointes, historique) et se ferme si
/// l'achat est supprimé.
class _PurchaseDetailPage extends ConsumerWidget {
  const _PurchaseDetailPage({
    required this.purchaseId,
    required this.initial,
    required this.projectNamesById,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onChangeStatus,
  });

  final String purchaseId;
  final Purchase initial;
  final Map<String, String> projectNamesById;
  final Future<void> Function(Purchase purchase) onEdit;
  final Future<bool> Function(Purchase purchase) onDelete;
  final Future<void> Function(Purchase purchase, String projectName) onPrint;
  final Future<void> Function(Purchase purchase, String status) onChangeStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [
      ...?ref.watch(activePurchasesProvider).value,
      ...?ref.watch(archivedPurchasesProvider).value,
    ];
    final purchase =
        all.where((p) => p.id == purchaseId).firstOrNull ?? initial;
    final projectName =
        projectNamesById[purchase.projectId] ?? purchase.projectId;
    final itemsAsync = ref.watch(purchaseItemsProvider(purchase.id));
    final items = itemsAsync.value ?? const <PurchaseItem>[];
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    final dateText = DateFormat('dd/MM/yyyy').format(purchase.createdAt);
    final snapshot = (hasData: itemsAsync.hasValue);
    final color = _statusColor(purchase.status);

    Future<void> onEditThis() => onEdit(purchase);
    Future<void> onPrintThis() => onPrint(purchase, projectName);
    Future<void> onChangeStatusThis(String status) =>
        onChangeStatus(purchase, status);
    Future<void> onDeleteThis() async {
      final deleted = await onDelete(purchase);
      if (deleted && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(purchase.title),
        actions: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatusChip(status: purchase.status),
                  if (purchase.orderNumber != null)
                    _InfoBadge(
                      icon: Icons.receipt_outlined,
                      label: purchase.orderNumber!,
                    ),
                  PurchaseAttachButton(purchase: purchase),
                ]),
                const SizedBox(height: 10),
                Text(
                  'Total : ${total.toStringAsFixed(2)} DA',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: PurchaseStepper(
              status: purchase.status,
              // Appui sur une étape : avancer ou revenir en arrière.
              onSelect: (step) async {
                if (step == purchase.status) {
                  return;
                }
                final back = PurchaseWorkflow.isBackward(purchase.status, step);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(back
                        ? 'Revenir à « ${PurchaseWorkflow.label(step)} » ?'
                        : 'Passer à « ${PurchaseWorkflow.label(step)} » ?'),
                    content: Text(back
                        ? 'Les dates des étapes suivantes seront effacées. '
                            'Le n° de commande est conservé et le retour est '
                            'noté dans le suivi.'
                        : 'Le changement est noté dans le suivi de l’achat.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Confirmer'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await onChangeStatusThis(step);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _FramedSection(
            title: 'Informations',
            icon: Icons.info_outline,
            color: context.palette.petrol,
            children: [
              _PurchaseMetaSection(
                purchase: purchase,
                projectName: projectName,
                createdAtLabel: dateText,
              ),
              if (purchase.supplierId != null) ...[
                const SizedBox(height: 8),
                PartyContactChips.supplier(purchase.supplierId),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _FramedSection(
            title: 'Articles',
            icon: Icons.inventory_2_outlined,
            color: context.palette.info,
            children: [
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _PurchaseItemsSection(items: items),
                const SizedBox(height: 12),
                _PurchaseTotalCard(total: total),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _FramedSection(
            title: 'Suivi',
            icon: Icons.timeline,
            color: Colors.teal,
            children: [PurchaseTimeline(purchase: purchase, showTitle: false)],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEditThis,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier'),
              ),
              OutlinedButton.icon(
                onPressed: onPrintThis,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => printPurchaseState(
                  context,
                  ref,
                  purchase: purchase,
                  projectName: projectName,
                ),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('État + pièces jointes'),
              ),
              if (PurchaseWorkflow.previousStep(purchase.status) != null)
                OutlinedButton.icon(
                  onPressed: () => onChangeStatusThis(
                      PurchaseWorkflow.previousStep(purchase.status)!),
                  icon: const Icon(Icons.undo),
                  label: Text(
                      'Revenir à « ${PurchaseWorkflow.label(PurchaseWorkflow.previousStep(purchase.status)!)} »'),
                ),
              if (purchase.status == 'annule' || purchase.status == 'archive')
                OutlinedButton.icon(
                  onPressed: () => onChangeStatusThis('brouillon'),
                  icon: const Icon(Icons.restore),
                  label: const Text('Rétablir (besoin émis)'),
                ),
              for (final next in PurchaseWorkflow.nextSteps(purchase.status))
                FilledButton.icon(
                  onPressed: () => onChangeStatusThis(next),
                  icon: Icon(switch (next) {
                    'dg_valide' => Icons.verified_outlined,
                    'en_traitement' => Icons.manage_accounts_outlined,
                    'commande' => Icons.shopping_cart_checkout_outlined,
                    _ => Icons.inventory_2_outlined,
                  }),
                  label: Text(PurchaseWorkflow.actionLabel(next)),
                ),
              if (purchase.status != 'annule' && purchase.status != 'archive')
                TextButton.icon(
                  onPressed: () => onChangeStatusThis('annule'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annuler'),
                ),
              if (purchase.status == 'livre' || purchase.status == 'annule')
                TextButton.icon(
                  onPressed: () => onChangeStatusThis('archive'),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiver'),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: onDeleteThis,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FramedSection(
            title: 'Pièces jointes (devis, proforma, photos)',
            icon: Icons.attach_file,
            color: Colors.indigo,
            children: [
              PurchaseDocumentsSection(
                  purchaseId: purchase.id, projectId: purchase.projectId)
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Sous-module de la fiche : seul son cadre porte la couleur qui le
/// distingue des autres.
class _FramedSection extends StatelessWidget {
  const _FramedSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            SignatureIcon(icon, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PurchaseMetaSection extends StatelessWidget {
  const _PurchaseMetaSection({
    required this.purchase,
    required this.projectName,
    required this.createdAtLabel,
  });

  final Purchase purchase;
  final String projectName;
  final String createdAtLabel;

  @override
  Widget build(BuildContext context) {
    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (purchase.orderNumber != null) ...[
            _MetaRow(label: 'N° commande', value: purchase.orderNumber!),
            const SizedBox(height: 8),
          ],
          _MetaRow(label: 'Projet', value: projectName),
          const SizedBox(height: 8),
          _MetaRow(label: 'Lot', value: purchase.lot),
          const SizedBox(height: 8),
          _MetaRow(label: 'Date', value: createdAtLabel),
          const SizedBox(height: 8),
          _MetaRow(label: 'Statut', value: _statusLabel(purchase.status)),
          const SizedBox(height: 8),
          _MetaRow(
            label: 'Observations',
            value: purchase.notes.isEmpty ? '-' : purchase.notes,
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemsSection extends StatelessWidget {
  const _PurchaseItemsSection({required this.items});

  final List<PurchaseItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const PremiumSurfaceCard(
        padding: EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Aucune ligne article.'),
        ),
      );
    }

    return PremiumSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Article',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qté',
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PU',
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.end,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total',
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.article,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (item.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.quantity.toStringAsFixed(2)} ${item.unit}',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.unitPrice.toStringAsFixed(2),
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.total.toStringAsFixed(2),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (item.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Remarque : ${item.notes}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _PurchaseTotalCard extends StatelessWidget {
  const _PurchaseTotalCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return PremiumSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total achat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text('Montant cumulé des lignes'),
              ],
            ),
          ),
          Text(
            total.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: color, width: 1.8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: TextStyle(
        color: color,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'brouillon':
      return Colors.blueGrey;
    case 'dg_valide':
      return Colors.blue;
    case 'en_traitement':
      return Colors.teal;
    case 'commande':
      return Colors.orange;
    case 'livre':
      return Colors.green;
    case 'annule':
      return Colors.red;
    case 'archive':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

String _statusLabel(String status) => PurchaseWorkflow.label(status);
