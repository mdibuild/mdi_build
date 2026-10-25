import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/tax_rate.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/module_filters.dart';
import 'providers/tax_rates_providers.dart';
import 'tax_rate_form_dialog.dart';

class TaxRatesPage extends ConsumerStatefulWidget {
  const TaxRatesPage({super.key});

  @override
  ConsumerState<TaxRatesPage> createState() => _TaxRatesPageState();
}

class _TaxRatesPageState extends ConsumerState<TaxRatesPage> {
  String _query = '';
  String _defaultFilter = 'all';

  List<TaxRate> _filter(List<TaxRate> rates) => rates.where((rate) {
        final textMatch = '${rate.label} ${rate.rate}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase());
        return textMatch &&
            (_defaultFilter == 'all' ||
                (_defaultFilter == 'default'
                    ? rate.isDefault
                    : !rate.isDefault));
      }).toList();

  Future<void> _openForm({TaxRate? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => TaxRateFormDialog(existing: existing),
    );

    if (saved == true) {
      ref.invalidate(activeTaxRatesProvider);
      ref.invalidate(archivedTaxRatesProvider);
    }
  }

  Future<void> _toggleArchive(TaxRate taxRate) async {
    await ref.read(taxRatesRepositoryProvider).setArchived(
          taxRateId: taxRate.id,
          archived: !taxRate.isArchived,
        );

    ref.invalidate(activeTaxRatesProvider);
    ref.invalidate(archivedTaxRatesProvider);
  }

  Future<void> _delete(TaxRate taxRate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer taux'),
        content: Text('Supprimer "${taxRate.label}" ?'),
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
      return;
    }

    await ref.read(taxRatesRepositoryProvider).deleteTaxRate(taxRate.id);

    ref.invalidate(activeTaxRatesProvider);
    ref.invalidate(archivedTaxRatesProvider);
  }

  Widget _buildList(AsyncValue<List<TaxRate>> async,
      {required bool archivedTab}) {
    return async.when(
      data: (rates) {
        final filtered = _filter(rates);
        if (filtered.isEmpty) {
          return const Center(child: Text('Aucun taux pour ces filtres.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final taxRate = filtered[index];

            return PremiumSurfaceCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: taxRate.isDefault
                    ? const Icon(Icons.star, color: Colors.amber)
                    : const Icon(Icons.percent_outlined),
                title: Text(taxRate.label),
                subtitle: Text('${taxRate.rate.toStringAsFixed(2)} %'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openForm(existing: taxRate);
                        break;
                      case 'archive':
                        _toggleArchive(taxRate);
                        break;
                      case 'delete':
                        _delete(taxRate);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(archivedTab ? 'Désarchiver' : 'Archiver'),
                    ),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur : $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeTaxRatesProvider);
    final archivedAsync = ref.watch(archivedTaxRatesProvider);

    return DefaultTabController(
      length: 2,
      child: ProjectModuleScaffold(
        appBar: AppBar(
          title: const Text('Taxes & TVA'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Actifs'),
              Tab(text: 'Archivés'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau taux'),
        ),
        body: AdaptiveHeaderColumn(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ModuleFilterBar(
                searchQuery: _query,
                searchHint: 'Libellé ou taux…',
                onSearchChanged: (value) => setState(() => _query = value),
                filters: [
                  ModuleFilterDropdown<String>(
                    value: _defaultFilter,
                    label: 'Utilisation',
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('Tous les taux')),
                      DropdownMenuItem(
                          value: 'default', child: Text('Taux par défaut')),
                      DropdownMenuItem(
                          value: 'other', child: Text('Autres taux')),
                    ],
                    onChanged: (value) =>
                        setState(() => _defaultFilter = value ?? 'all'),
                  ),
                ],
                onReset: () => setState(() {
                  _query = '';
                  _defaultFilter = 'all';
                }),
                resultLabel:
                    '${_filter(activeAsync.value ?? []).length} actif(s) · '
                    '${_filter(archivedAsync.value ?? []).length} archivé(s)',
              ),
            ),
            Expanded(
                child: TabBarView(children: [
              _buildList(activeAsync, archivedTab: false),
              _buildList(archivedAsync, archivedTab: true),
            ])),
          ],
        ),
      ),
    );
  }
}
