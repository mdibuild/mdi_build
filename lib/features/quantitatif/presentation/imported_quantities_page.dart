import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/quantity_item.dart';
import '../../../core/utils/number_input.dart';
import '../../../shared/presentation/excel_import_dialog.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/project_module_scaffold.dart';
import '../../achats/presentation/purchase_draft_dialog.dart';
import '../../metrage/presentation/providers/spaces_providers.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';

/// Quantités importées depuis un fichier Excel (Désignation, Quantité,
/// Unité, Total) : consultables ici, reprises dans un devis ou un achat.
class ImportedQuantitiesPage extends ConsumerStatefulWidget {
  const ImportedQuantitiesPage({super.key});

  @override
  ConsumerState<ImportedQuantitiesPage> createState() =>
      _ImportedQuantitiesPageState();
}

class _ImportedQuantitiesPageState
    extends ConsumerState<ImportedQuantitiesPage> {
  String _query = '';
  bool _busy = false;

  Future<void> _import(String projectId) async {
    final selection = await pickQuantitiesFromExcel(context);
    if (selection == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) {
        throw StateError('Profil introuvable');
      }
      final existing = ref.read(quantityItemsProvider(projectId)).value ?? [];
      await ref.read(quantityItemsRepositoryProvider).addItems([
        for (var i = 0; i < selection.lines.length; i++)
          QuantityItem(
            id: '',
            companyId: profile.companyId,
            projectId: projectId,
            label: selection.lines[i].label,
            quantity: selection.lines[i].quantity,
            unit: selection.lines[i].unit,
            unitPrice: selection.lines[i].unitPrice,
            total: selection.lines[i].total,
            sourceFile: selection.fileName,
            sortOrder: existing.length + i,
            createdBy: profile.id,
          ),
      ]);
      ref.invalidate(quantityItemsProvider(projectId));
      _snack('${selection.lines.length} ligne(s) importée(s) depuis '
          '${selection.fileName}.');
    } catch (error) {
      _snack('Import impossible : $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clear(String projectId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer les quantités importées'),
        content: const Text(
            'Toutes les lignes importées de ce chantier seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: PremiumButtonStyles.destructive(context),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await ref.read(quantityItemsRepositoryProvider).deleteAll(projectId);
      ref.invalidate(quantityItemsProvider(projectId));
    } catch (error) {
      _snack('Suppression impossible : $error');
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(selectedProjectProvider).value;
    final money = NumberFormat('#,##0.00', 'fr_FR');
    return ProjectModuleScaffold(
      appBar: AppBar(title: const Text('Quantités importées')),
      body: project == null
          ? const Center(child: Text('Choisis un chantier.'))
          : ref.watch(quantityItemsProvider(project.id)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '$error'.contains('project_quantity_items')
                          ? 'L’import Excel n’est pas encore activé dans la '
                              'base (script SQL 2026_discounts_imports_'
                              'purchase_tracking.sql).'
                          : 'Quantités indisponibles : $error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (items) {
                  final q = _query.trim().toLowerCase();
                  final shown = items
                      .where((i) =>
                          q.isEmpty ||
                          '${i.label} ${i.unit} ${i.sourceFile}'
                              .toLowerCase()
                              .contains(q))
                      .toList();
                  final sum =
                      shown.fold<double>(0, (s, i) => s + (i.total ?? 0));
                  final files = {for (final i in items) i.sourceFile}
                    ..remove('');
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      PremiumHeroHeader(
                        title: 'Quantités importées',
                        subtitle: files.isEmpty
                            ? 'Importe un tableau Excel : Désignation, '
                                'Quantité, Unité, Total.'
                            : 'Fichier(s) : ${files.join(', ')}',
                        trailing: FilledButton.icon(
                          onPressed: _busy ? null : () => _import(project.id),
                          icon: _busy
                              ? const PremiumButtonProgress()
                              : const Icon(Icons.upload_file_outlined),
                          label: const Text('Importer un fichier Excel'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (items.isNotEmpty) ...[
                        ModuleFilterBar(
                          searchQuery: _query,
                          onSearchChanged: (v) => setState(() => _query = v),
                          searchHint: 'Désignation, unité, fichier…',
                          resultLabel:
                              '${shown.length} ligne(s) sur ${items.length} · '
                              'total ${money.format(sum)} DA',
                          onReset: () => setState(() => _query = ''),
                          filters: const [],
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          OutlinedButton.icon(
                            onPressed: () => showPurchaseDraftDialog(
                              context,
                              ref,
                              projectId: project.id,
                              projectName: project.name,
                              title: 'Achat depuis le quantitatif',
                              lot: 'Quantitatif',
                              notes: 'Généré depuis les quantités importées.',
                              lines: [
                                for (final i in shown)
                                  PurchaseDraftLine(
                                    article: i.label,
                                    quantity: i.quantity,
                                    unit: i.unit,
                                  ),
                              ],
                            ),
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                            label: const Text('Créer un achat'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _clear(project.id),
                            icon: Icon(Icons.delete_sweep_outlined,
                                color: context.palette.danger),
                            label: const Text('Tout effacer'),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'Pour un devis : ouvre un devis puis « Reprendre le '
                          'quantitatif ».',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        PremiumSurfaceCard(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Désignation')),
                                DataColumn(label: Text('Qté'), numeric: true),
                                DataColumn(label: Text('Unité')),
                                DataColumn(label: Text('PU'), numeric: true),
                                DataColumn(label: Text('Total'), numeric: true),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final i in shown)
                                  DataRow(cells: [
                                    DataCell(ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 340),
                                      child: Text(i.label,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2),
                                    )),
                                    DataCell(Text(formatDecimal(i.quantity))),
                                    DataCell(Text(i.unit)),
                                    DataCell(Text(i.effectiveUnitPrice == null
                                        ? '—'
                                        : money.format(i.effectiveUnitPrice))),
                                    DataCell(Text(i.total == null
                                        ? '—'
                                        : money.format(i.total))),
                                    DataCell(IconButton(
                                      tooltip: 'Supprimer la ligne',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () async {
                                        await ref
                                            .read(
                                                quantityItemsRepositoryProvider)
                                            .deleteItem(i.id);
                                        ref.invalidate(
                                            quantityItemsProvider(project.id));
                                      },
                                    )),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        const PremiumSurfaceCard(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Aucune quantité importée. Prépare un tableau '
                              'Excel avec les colonnes Désignation, Quantité, '
                              'Unité et Total (ou Prix unitaire), puis '
                              'importe-le.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
    );
  }
}
