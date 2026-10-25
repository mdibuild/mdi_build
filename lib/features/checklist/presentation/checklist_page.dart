import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/checklist_item.dart';
import '../../../core/providers/module_refresh_provider.dart';
import '../../../shared/presentation/party_pickers.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../../shared/presentation/project_module_scaffold.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../../settings/presentation/providers/clients_providers.dart';
import '../../settings/presentation/providers/suppliers_providers.dart';
import '../data/checklist_repository.dart';

final checklistRepositoryProvider =
    Provider<ChecklistRepository>((ref) => ChecklistRepository());

/// Check-list du chantier [projectId] (éléments généraux inclus) ; null =
/// toute l'entreprise.
final checklistItemsProvider =
    FutureProvider.family<List<ChecklistItem>, String?>((ref, projectId) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }
  return ref
      .read(checklistRepositoryProvider)
      .fetchItems(companyId: profile.companyId, projectId: projectId);
});

class ChecklistPage extends ConsumerStatefulWidget {
  const ChecklistPage({super.key});

  @override
  ConsumerState<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends ConsumerState<ChecklistPage> {
  final _input = TextEditingController();
  bool _allProjects = false;
  bool _general = false;
  String _filter = 'todo';
  DateTime? _due;
  String? _clientId;
  String? _supplierId;
  bool _moreOptions = false;
  bool _adding = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(String? projectId) async {
    final title = _input.text.trim();
    if (title.isEmpty || _adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) {
        throw StateError('Profil introuvable');
      }
      await ref.read(checklistRepositoryProvider).addItem(ChecklistItem(
            id: '',
            companyId: profile.companyId,
            projectId: _general ? null : projectId,
            title: title,
            isDone: false,
            dueDate: _due,
            clientId: _clientId,
            supplierId: _supplierId,
            createdBy: profile.id,
            createdAt: DateTime.now(),
          ));
      _input.clear();
      setState(() {
        _due = null;
        _clientId = null;
        _supplierId = null;
      });
      ref.invalidate(checklistItemsProvider);
    } catch (error) {
      _snack('Ajout impossible : $error');
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(checklistItemsProvider);
    } catch (error) {
      _snack('Erreur : $error');
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
    final scopeId = _allProjects ? null : project?.id;
    final itemsAsync = ref.watch(checklistItemsProvider(scopeId));
    final names = <String, String>{
      for (final c in ref.watch(activeClientsProvider).value ?? const [])
        c.id: c.name,
      for (final s in ref.watch(activeSuppliersProvider).value ?? const [])
        s.id: s.name,
    };
    final colors = context.palette;

    return ProjectModuleScaffold(
      appBar: AppBar(title: const Text('Check-list')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PremiumSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(project?.id),
                      decoration: InputDecoration(
                        hintText: _general || project == null
                            ? 'Ajouter une chose à faire (générale)…'
                            : 'Ajouter une chose à faire pour ${project.name}…',
                        prefixIcon: const Icon(Icons.add_task),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Ajouter',
                    onPressed: _adding ? null : () => _add(project?.id),
                    icon: _adding
                        ? const PremiumButtonProgress()
                        : const Icon(Icons.arrow_upward),
                  ),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _moreOptions = !_moreOptions),
                    icon: Icon(
                        _moreOptions ? Icons.expand_less : Icons.tune_outlined),
                    label: Text(_moreOptions
                        ? 'Moins d’options'
                        : 'Échéance, client, fournisseur…'),
                  ),
                ),
                if (_moreOptions) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _due ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _due = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_due == null
                          ? 'Échéance'
                          : 'Pour le ${DateFormat('dd/MM/yyyy').format(_due!)}'),
                    ),
                    FilterChip(
                      label: const Text('Générale (tous chantiers)'),
                      selected: _general,
                      onSelected: (v) => setState(() => _general = v),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ClientPickerField(
                    label: 'Client concerné',
                    value: _clientId,
                    onChanged: (id, _) => setState(() => _clientId = id),
                  ),
                  const SizedBox(height: 8),
                  SupplierPickerField(
                    label: 'Fournisseur concerné',
                    value: _supplierId,
                    onChanged: (id, _) => setState(() => _supplierId = id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todo', label: Text('À faire')),
                ButtonSegment(value: 'done', label: Text('Faites')),
                ButtonSegment(value: 'all', label: Text('Toutes')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            FilterChip(
              label: const Text('Tous les chantiers'),
              selected: _allProjects,
              onSelected: (v) => setState(() => _allProjects = v),
            ),
          ]),
          const SizedBox(height: 12),
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => PremiumSurfaceCard(
              child: Text(
                '$error'.contains('checklist_items')
                    ? 'La check-list n’est pas encore activée dans la base '
                        '(script SQL 2026_invoices_checklist_realtime.sql).'
                    : 'Check-list indisponible : $error',
              ),
            ),
            data: (items) {
              final todo = items.where((i) => !i.isDone).length;
              final shown = items
                  .where((i) => switch (_filter) {
                        'todo' => !i.isDone,
                        'done' => i.isDone,
                        _ => true,
                      })
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          '$todo à faire · ${items.length - todo} faite(s)',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    if (items.any((i) => i.isDone))
                      TextButton(
                        onPressed: () async {
                          final profile =
                              await ref.read(currentProfileProvider.future);
                          if (profile == null) {
                            return;
                          }
                          await _run(() =>
                              ref.read(checklistRepositoryProvider).deleteDone(
                                    companyId: profile.companyId,
                                    projectId: scopeId,
                                  ));
                        },
                        child: const Text('Effacer les faites'),
                      ),
                  ]),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        items.isEmpty
                            ? 'Rien à faire pour l’instant. Ajoute une première tâche ci-dessus.'
                            : 'Aucun élément dans cette vue.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    PremiumSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final item in shown)
                          _ChecklistTile(
                            key: ValueKey(item.id),
                            item: item,
                            linkedName:
                                names[item.clientId] ?? names[item.supplierId],
                            general: item.projectId == null,
                            danger: colors.danger,
                            onToggle: (v) => _run(() => ref
                                .read(checklistRepositoryProvider)
                                .setDone(item.id, v)),
                            onDelete: () => _run(() => ref
                                .read(checklistRepositoryProvider)
                                .deleteItem(item.id)),
                          ),
                      ]),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    super.key,
    required this.item,
    required this.linkedName,
    required this.general,
    required this.danger,
    required this.onToggle,
    required this.onDelete,
  });

  final ChecklistItem item;
  final String? linkedName;
  final bool general;
  final Color danger;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue();
    final details = [
      if (item.dueDate != null)
        '${overdue ? 'En retard · ' : ''}pour le ${DateFormat('dd/MM/yyyy').format(item.dueDate!)}',
      if (linkedName != null) linkedName!,
      if (general) 'Générale',
    ];
    return CheckboxListTile(
      value: item.isDone,
      onChanged: (v) => onToggle(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.isDone ? TextDecoration.lineThrough : null,
          color: item.isDone ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              style: TextStyle(color: overdue ? danger : null),
            ),
      secondary: IconButton(
        tooltip: 'Supprimer',
        onPressed: onDelete,
        icon: const Icon(Icons.close),
      ),
    );
  }
}
