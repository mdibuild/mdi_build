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
import '../../../core/services/notify_event_service.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import '../services/checklist_reminders.dart';
import '../../../core/models/settings_user_entry.dart';
import '../../projects/presentation/providers/project_scope_provider.dart';

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
  return ref.read(checklistRepositoryProvider).fetchItems(
        companyId: profile.companyId,
        projectId: projectId,
        // Les tâches qui me sont destinées apparaissent quel que soit le
        // chantier sélectionné.
        assignedTo: profile.id,
      );
});

class ChecklistPage extends ConsumerStatefulWidget {
  const ChecklistPage({super.key});

  @override
  ConsumerState<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends ConsumerState<ChecklistPage> {
  final _input = TextEditingController();
  bool _allProjects = false;
  bool _mineOnly = false;
  bool _general = false;
  String _filter = 'todo';

  /// Échéance (date et heure) ; null = sans échéance.
  DateTime? _due;
  String? _assignedTo;

  /// Rappel en minutes avant l'échéance (null = aucun).
  int? _reminder = 0;
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
            dueDate: _due == null
                ? null
                : DateTime(_due!.year, _due!.month, _due!.day),
            dueAt: _due,
            assignedTo: _assignedTo,
            reminderMinutes: _reminder,
            clientId: _clientId,
            supplierId: _supplierId,
            createdBy: profile.id,
            createdAt: DateTime.now(),
          ));
      // Prévenir tout de suite la personne à qui la tâche est destinée.
      final assignee = _assignedTo;
      if (assignee != null && assignee != profile.id) {
        await NotifyEventService.send(
          companyId: profile.companyId,
          projectId: _general ? null : projectId,
          module: 'planning',
          title: 'Nouvelle tâche pour vous',
          body: _due == null
              ? title
              : '$title — pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(_due!)}',
          data: const {'type': 'checklist'},
          recipientProfileId: assignee,
        );
      }
      _input.clear();
      setState(() {
        _due = null;
        _assignedTo = null;
        _reminder = 0;
        _clientId = null;
        _supplierId = null;
      });
      ref.invalidate(checklistItemsProvider);
      ref.invalidate(checklistRemindersSyncProvider);
    } catch (error) {
      _snack('Ajout impossible : $error');
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _pickDueDateTime() async {
    final initial = _due ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Heure de l’échéance',
    );
    if (!mounted) {
      return;
    }
    final t = time ?? const TimeOfDay(hour: 9, minute: 0);
    setState(() =>
        _due = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  /// Fenêtre « Modifier la tâche » : titre, échéance (date et heure),
  /// rappel, destinataire, ou suppression.
  Future<void> _edit(ChecklistItem item) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ChecklistEditSheet(item: item),
    );
    if (result == null || !mounted) {
      return;
    }
    final repo = ref.read(checklistRepositoryProvider);
    if (result.delete) {
      await _run(() => repo.deleteItem(item.id));
      _snack('Tâche supprimée.');
      return;
    }
    final updated = result.item!;
    await _run(() async {
      await repo.updateItem(updated);
      final profile = await ref.read(currentProfileProvider.future);
      final assignee = updated.assignedTo;
      // Nouveau destinataire, ou échéance déplacée : il est prévenu.
      final creator = item.createdBy;
      if (profile != null &&
          creator != null &&
          creator != profile.id &&
          updated.dueAt != item.dueAt) {
        await NotifyEventService.send(
          companyId: profile.companyId,
          projectId: updated.projectId,
          module: 'planning',
          title: 'Échéance modifiée',
          body: '${updated.title} — par ${profile.fullName}',
          data: const {'type': 'checklist'},
          recipientProfileId: creator,
        );
      }
      if (profile != null &&
          assignee != null &&
          assignee != profile.id &&
          (assignee != item.assignedTo || updated.dueAt != item.dueAt)) {
        await NotifyEventService.send(
          companyId: profile.companyId,
          projectId: updated.projectId,
          module: 'planning',
          title: assignee != item.assignedTo
              ? 'Nouvelle tâche pour vous'
              : 'Échéance modifiée',
          body: updated.dueAt == null
              ? updated.title
              : '${updated.title} — pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(updated.dueAt!)}',
          data: const {'type': 'checklist'},
          recipientProfileId: assignee,
        );
      }
    });
    _snack('Tâche modifiée.');
  }

  /// Faite / à refaire. L'autre personne concernée (émetteur ou
  /// destinataire) est prévenue.
  Future<void> _toggle(ChecklistItem item, bool done) async {
    await _run(
        () => ref.read(checklistRepositoryProvider).setDone(item.id, done));
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) {
      return;
    }
    final other =
        profile.id == item.createdBy ? item.assignedTo : item.createdBy;
    if (other == null || other == profile.id) {
      return;
    }
    await NotifyEventService.send(
      companyId: profile.companyId,
      projectId: item.projectId,
      module: 'planning',
      title: done ? 'Tâche faite' : 'Tâche rouverte',
      body: '${item.title} — par ${profile.fullName}',
      data: const {'type': 'checklist'},
      recipientProfileId: other,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(checklistItemsProvider);
      ref.invalidate(checklistRemindersSyncProvider);
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
    final scopeId =
        _allProjects || ref.watch(projectScopeAllProvider) ? null : project?.id;
    final itemsAsync = ref.watch(checklistItemsProvider(scopeId));
    final names = <String, String>{
      for (final c in ref.watch(activeClientsProvider).value ?? const [])
        c.id: c.name,
      for (final s in ref.watch(activeSuppliersProvider).value ?? const [])
        s.id: s.name,
    };
    final colors = context.palette;
    final profile = ref.watch(currentProfileProvider).value;
    final users = <String, String>{
      if (profile != null)
        for (final u
            in ref.watch(companyUsersProvider(profile.companyId)).value ??
                const [])
          u.id: u.displayName,
    };

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
                        : 'Échéance, destinataire, rappel…'),
                  ),
                ),
                if (_moreOptions) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _pickDueDateTime,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_due == null
                          ? 'Échéance (date et heure)'
                          : 'Pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(_due!)}'),
                    ),
                    if (_due != null)
                      IconButton(
                        tooltip: 'Retirer l’échéance',
                        onPressed: () => setState(() => _due = null),
                        icon: const Icon(Icons.event_busy_outlined),
                      ),
                    if (_due != null)
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _reminder,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Rappel',
                            prefixIcon: Icon(Icons.alarm),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 0, child: Text('À l’heure')),
                            DropdownMenuItem(
                                value: 15, child: Text('15 min avant')),
                            DropdownMenuItem(
                                value: 60, child: Text('1 h avant')),
                            DropdownMenuItem(
                                value: 1440, child: Text('1 jour avant')),
                            DropdownMenuItem(
                                value: null, child: Text('Pas de rappel')),
                          ],
                          onChanged: (v) => setState(() => _reminder = v),
                        ),
                      ),
                    FilterChip(
                      label: const Text('Générale (tous chantiers)'),
                      selected: _general,
                      onSelected: (v) => setState(() => _general = v),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _AssigneeField(
                    value: _assignedTo,
                    onChanged: (id) => setState(() => _assignedTo = id),
                  ),
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
            FilterChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: const Text('Pour moi'),
              selected: _mineOnly,
              onSelected: (v) => setState(() => _mineOnly = v),
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
              final me = profile?.id;
              final shown = items
                  .where((i) => !_mineOnly || i.assignedTo == me)
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
                            assigneeName: users[item.assignedTo],
                            creatorName: users[item.createdBy],
                            general: item.projectId == null,
                            danger: colors.danger,
                            onToggle: (v) => _toggle(item, v),
                            onEdit: () => _edit(item),
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
    this.assigneeName,
    this.creatorName,
    required this.general,
    required this.danger,
    required this.onToggle,
    required this.onEdit,
  });

  final ChecklistItem item;
  final String? linkedName;
  final String? assigneeName;
  final String? creatorName;
  final bool general;
  final Color danger;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue();
    final details = [
      if (item.dueAt != null)
        '${overdue ? 'En retard · ' : ''}pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(item.dueAt!)}'
            '${item.reminderMinutes == null || item.isDone ? '' : ' 🔔'}'
      else if (item.dueDate != null)
        '${overdue ? 'En retard · ' : ''}pour le ${DateFormat('dd/MM/yyyy').format(item.dueDate!)}',
      if (creatorName != null) 'De : $creatorName',
      if (assigneeName != null) 'Pour : $assigneeName',
      if (linkedName != null) linkedName!,
      if (general) 'Générale',
    ];
    // Appui court : faite / à refaire. Appui long : modifier ou supprimer.
    return ListTile(
      onTap: () => onToggle(!item.isDone),
      onLongPress: onEdit,
      leading: Checkbox(
        value: item.isDone,
        onChanged: (v) => onToggle(v ?? false),
      ),
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
      trailing: IconButton(
        tooltip: 'Modifier (ou appui long)',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

/// Choix de la personne à qui la tâche est destinée (utilisateurs de
/// l'entreprise).
class _AssigneeField extends ConsumerWidget {
  const _AssigneeField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final users = profile == null
        ? const <SettingsUserEntry>[]
        : ref.watch(companyUsersProvider(profile.companyId)).value ??
            const <SettingsUserEntry>[];
    final known = users.any((u) => u.id == value);
    return DropdownButtonFormField<String?>(
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Destinée à',
        prefixIcon: Icon(Icons.person_pin_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('— Personne en particulier —'),
        ),
        for (final u in users)
          DropdownMenuItem<String?>(
            value: u.id,
            child: Text(
              u.id == profile?.id ? '${u.displayName} (moi)' : u.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _EditResult {
  const _EditResult.save(ChecklistItem this.item) : delete = false;
  const _EditResult.delete()
      : item = null,
        delete = true;

  final ChecklistItem? item;
  final bool delete;
}

class _ChecklistEditSheet extends StatefulWidget {
  const _ChecklistEditSheet({required this.item});

  final ChecklistItem item;

  @override
  State<_ChecklistEditSheet> createState() => _ChecklistEditSheetState();
}

class _ChecklistEditSheetState extends State<_ChecklistEditSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item.title);
  late DateTime? _due = widget.item.dueAt ??
      (widget.item.dueDate == null
          ? null
          : DateTime(widget.item.dueDate!.year, widget.item.dueDate!.month,
              widget.item.dueDate!.day, 9));
  late int? _reminder = widget.item.reminderMinutes;
  late String? _assignedTo = widget.item.assignedTo;
  bool _confirmDelete = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final initial = _due ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Heure de l’échéance',
    );
    if (!mounted) {
      return;
    }
    final t = time ?? TimeOfDay.fromDateTime(initial);
    setState(() =>
        _due = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.palette.danger;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modifier la tâche',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Tâche',
                prefixIcon: Icon(Icons.task_alt),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.event_outlined),
                label: Text(_due == null
                    ? 'Ajouter une échéance'
                    : 'Pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(_due!)}'),
              ),
              if (_due != null)
                TextButton.icon(
                  onPressed: () => setState(() => _due = null),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Retirer l’échéance'),
                ),
            ]),
            if (_due != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _reminder,
                decoration: const InputDecoration(
                  labelText: 'Rappel',
                  prefixIcon: Icon(Icons.alarm),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('À l’heure')),
                  DropdownMenuItem(value: 15, child: Text('15 min avant')),
                  DropdownMenuItem(value: 60, child: Text('1 h avant')),
                  DropdownMenuItem(value: 1440, child: Text('1 jour avant')),
                  DropdownMenuItem(value: null, child: Text('Pas de rappel')),
                ],
                onChanged: (v) => setState(() => _reminder = v),
              ),
            ],
            const SizedBox(height: 12),
            _AssigneeField(
              value: _assignedTo,
              onChanged: (id) => setState(() => _assignedTo = id),
            ),
            const SizedBox(height: 20),
            if (_confirmDelete)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Supprimer définitivement cette tâche ?',
                      style: TextStyle(
                          color: danger, fontWeight: FontWeight.w700)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: danger),
                    onPressed: () =>
                        Navigator.of(context).pop(const _EditResult.delete()),
                    child: const Text('Oui, supprimer'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: const Text('Non'),
                  ),
                ],
              )
            else
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: danger),
                      onPressed: () => setState(() => _confirmDelete = true),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final title = _title.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop(_EditResult.save(
                          widget.item.copyWith(
                            title: title,
                            dueAt: _due,
                            clearDue: _due == null,
                            reminderMinutes: _reminder,
                            clearReminder: _reminder == null,
                            assignedTo: _assignedTo,
                            clearAssignee: _assignedTo == null,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ]),
          ],
        ),
      ),
    );
  }
}
