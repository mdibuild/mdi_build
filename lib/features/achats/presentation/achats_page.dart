import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/app_scaffold_title.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/projects_providers.dart';
import '../services/purchase_pdf_service.dart';
import 'providers/purchases_providers.dart';
import 'widgets/purchase_form.dart';

class AchatsPage extends ConsumerStatefulWidget {
  const AchatsPage({super.key});

  @override
  ConsumerState<AchatsPage> createState() => _AchatsPageState();
}

class _AchatsPageState extends ConsumerState<AchatsPage> {
  final TextEditingController searchController = TextEditingController();
  String statusFilter = 'tous';

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

      await PurchasePdfService().printPurchase(
        purchase: purchase,
        projectName: projectName,
        items: items,
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

    await ref.read(purchasesRepositoryProvider).updatePurchaseStatus(
          purchaseId: purchase.id,
          status: status,
          actorId: authUser?.id,
        );

    ref.invalidate(activePurchasesProvider);
    ref.invalidate(archivedPurchasesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : ${_statusLabel(status)}')),
      );
    }
  }

  Future<void> _deletePurchase(
    BuildContext context, {
    required Purchase purchase,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer achat'),
        content: Text('Supprimer "${purchase.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(purchasesRepositoryProvider).deletePurchase(purchase.id);

    ref.invalidate(activePurchasesProvider);
    ref.invalidate(archivedPurchasesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Achat supprimé.')),
      );
    }
  }

  List<Purchase> _applyFilters(
    List<Purchase> purchases,
    Map<String, String> projectNamesById,
  ) {
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
          purchase.notes.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activePurchasesAsync = ref.watch(activePurchasesProvider);
    final archivedPurchasesAsync = ref.watch(archivedPurchasesProvider);
    final projectsAsync = ref.watch(projectsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Achats'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En cours'),
              Tab(text: 'Archivés'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Recherche',
                            hintText: 'Titre, lot, projet, remarque',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: statusFilter,
                          decoration:
                              const InputDecoration(labelText: 'Statut'),
                          items: const [
                            DropdownMenuItem(
                                value: 'tous', child: Text('Tous')),
                            DropdownMenuItem(
                                value: 'brouillon', child: Text('Brouillon')),
                            DropdownMenuItem(
                                value: 'dg_valide', child: Text('DG validé')),
                            DropdownMenuItem(
                                value: 'commande', child: Text('Commandé')),
                            DropdownMenuItem(
                                value: 'livre', child: Text('Livré')),
                            DropdownMenuItem(
                                value: 'annule', child: Text('Annulé')),
                            DropdownMenuItem(
                                value: 'archive', child: Text('Archivé')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => statusFilter = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: projectsAsync.when(
                  data: (projects) {
                    final projectNamesById = {
                      for (final project in projects) project.id: project.name,
                    };

                    return TabBarView(
                      children: [
                        activePurchasesAsync.when(
                          data: (purchases) => _PurchasesList(
                            purchases:
                                _applyFilters(purchases, projectNamesById),
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
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                        archivedPurchasesAsync.when(
                          data: (purchases) => _PurchasesList(
                            purchases:
                                _applyFilters(purchases, projectNamesById),
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
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Erreur projets: $error')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchasesList extends ConsumerWidget {
  const _PurchasesList({
    required this.purchases,
    required this.projectNamesById,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onChangeStatus,
  });

  final List<Purchase> purchases;
  final Map<String, String> projectNamesById;
  final Future<void> Function(Purchase purchase) onEdit;
  final Future<void> Function(Purchase purchase) onDelete;
  final Future<void> Function(Purchase purchase, String projectName) onPrint;
  final Future<void> Function(Purchase purchase, String status) onChangeStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (purchases.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucun achat.'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: purchases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final purchase = purchases[index];
          final projectName =
              projectNamesById[purchase.projectId] ?? purchase.projectId;

          return _PurchaseTile(
            purchase: purchase,
            projectName: projectName,
            onEdit: () => onEdit(purchase),
            onDelete: () => onDelete(purchase),
            onPrint: () => onPrint(purchase, projectName),
            onChangeStatus: (status) => onChangeStatus(purchase, status),
          );
        },
      ),
    );
  }
}

class _PurchaseTile extends ConsumerWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.projectName,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onChangeStatus,
  });

  final Purchase purchase;
  final String projectName;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onPrint;
  final Future<void> Function(String status) onChangeStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<PurchaseItem>>(
      future:
          ref.read(purchasesRepositoryProvider).fetchPurchaseItems(purchase.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final total = items.fold<double>(0, (sum, item) => sum + item.total);
        final dateText = DateFormat('dd/MM/yyyy').format(purchase.createdAt);

        return Card(
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    purchase.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoBadge(icon: Icons.work_outline, label: purchase.lot),
                      _InfoBadge(
                          icon: Icons.apartment_outlined, label: projectName),
                      _InfoBadge(
                          icon: Icons.calendar_today_outlined, label: dateText),
                      _StatusChip(status: purchase.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total : ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            children: [
              _PurchaseMetaSection(
                purchase: purchase,
                projectName: projectName,
                createdAtLabel: dateText,
              ),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                )
              else ...[
                _PurchaseItemsSection(items: items),
                const SizedBox(height: 12),
                _PurchaseTotalCard(total: total),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                  if (purchase.status == 'brouillon')
                    FilledButton.icon(
                      onPressed: () => onChangeStatus('dg_valide'),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('DG validé'),
                    ),
                  if (purchase.status == 'dg_valide')
                    FilledButton.icon(
                      onPressed: () => onChangeStatus('commande'),
                      icon: const Icon(Icons.shopping_cart_checkout_outlined),
                      label: const Text('Commander'),
                    ),
                  if (purchase.status == 'commande')
                    FilledButton.icon(
                      onPressed: () => onChangeStatus('livre'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Livré'),
                    ),
                  if (purchase.status != 'annule' &&
                      purchase.status != 'archive')
                    TextButton.icon(
                      onPressed: () => onChangeStatus('annule'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler'),
                    ),
                  if (purchase.status == 'livre' || purchase.status == 'annule')
                    TextButton.icon(
                      onPressed: () => onChangeStatus('archive'),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archiver'),
                    ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Aucune ligne article.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
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
      ),
    );
  }
}

class _PurchaseTotalCard extends StatelessWidget {
  const _PurchaseTotalCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
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
      backgroundColor: color.withValues(alpha: 0.14),
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

String _statusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'dg_valide':
      return 'DG validé';
    case 'commande':
      return 'Commandé';
    case 'livre':
      return 'Livré';
    case 'annule':
      return 'Annulé';
    case 'archive':
      return 'Archivé';
    default:
      return status;
  }
}
