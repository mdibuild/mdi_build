import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_task.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../services/planning_notifications_service.dart';
import '../services/planning_pdf_service.dart';
import 'gantt_view.dart';
import 'providers/planning_providers.dart';
import 'task_dependencies_panel.dart';
import 'task_form_page.dart';

class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  final TextEditingController searchController = TextEditingController();

  String statusFilter = 'tous';
  String priorityFilter = 'toutes';
  String? _lastNotificationSignature;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateTask(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TaskFormPage(),
      ),
    );
  }

  Future<void> _openEditTask(
    BuildContext context, {
    required ProjectTask task,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskFormPage(task: task),
      ),
    );
  }

  Future<void> _printPlanning({
    required String projectName,
    required List<ProjectTask> tasks,
  }) async {
    await PlanningPdfService().printPlanning(
      projectName: projectName,
      tasks: tasks,
    );
  }

  Future<void> _toggleArchive(ProjectTask task) async {
    await ref.read(planningRepositoryProvider).updateTask(
          task.copyWith(
            isArchived: !task.isArchived,
            status: !task.isArchived
                ? 'archivee'
                : task.status == 'archivee'
                    ? 'a_faire'
                    : task.status,
          ),
        );

    ref.invalidate(activeTasksProvider);
    ref.invalidate(archivedTasksProvider);
  }

  Future<void> _deleteTask(BuildContext context, ProjectTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer tÃƒÆ’Ã‚Â¢che'),
        content: Text('Supprimer "${task.title}" ?'),
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

    await ref.read(planningRepositoryProvider).deleteTask(task.id);
    ref.invalidate(activeTasksProvider);
    ref.invalidate(archivedTasksProvider);
    ref.invalidate(taskDependenciesProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TÃƒÆ’Ã‚Â¢che supprimÃƒÆ’Ã‚Â©e.')),
    );
  }

  List<ProjectTask> _applyFilters(List<ProjectTask> tasks) {
    final query = searchController.text.trim().toLowerCase();

    return tasks.where((task) {
      final matchesSearch = query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.lot.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      final matchesStatus =
          statusFilter == 'tous' || task.status == statusFilter;
      final matchesPriority =
          priorityFilter == 'toutes' || task.priority == priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();
  }

  void _schedulePlanningNotifications({
    required String projectName,
    required List<ProjectTask> tasks,
  }) {
    final activeDatedTasks = tasks
        .where(
          (task) =>
              !task.isArchived &&
              task.plannedStartDate != null &&
              task.plannedEndDate != null,
        )
        .toList();

    final signature = [
      projectName,
      for (final task in activeDatedTasks)
        [
          task.id,
          task.status,
          task.plannedStartDate?.millisecondsSinceEpoch ?? 0,
          task.plannedEndDate?.millisecondsSinceEpoch ?? 0,
          task.updatedAt.millisecondsSinceEpoch,
        ].join(':'),
    ].join('|');

    if (_lastNotificationSignature == signature) {
      return;
    }

    _lastNotificationSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await PlanningNotificationsService.instance.notifyForTasks(
        projectName: projectName,
        tasks: activeDatedTasks,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final activeTasksAsync = ref.watch(activeTasksProvider);
    final archivedTasksAsync = ref.watch(archivedTasksProvider);
    final dependenciesAsync = ref.watch(taskDependenciesProvider);
    final currentProject = selectedProjectAsync.asData?.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Planning'),
              bottom: TabBar(
                isScrollable: true,
                tabs: const [
                  Tab(text: 'En cours'),
                  Tab(text: 'ArchivÃƒÆ’Ã‚Â©es'),
                ],
              ),
            ),
            body: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 20),
              child: Column(
                children: [
                  selectedProjectAsync.when(
                    data: (project) => _PlanningHeader(
                      isCompact: isCompact,
                      projectName: project?.name,
                      onPrint: project == null
                          ? null
                          : () async {
                              final tasks =
                                  await ref.read(activeTasksProvider.future);
                              final filteredTasks = _applyFilters(tasks);
                              await _printPlanning(
                                projectName: project.name,
                                tasks: filteredTasks,
                              );
                            },
                      onCreateTask: project == null
                          ? null
                          : () => _openCreateTask(context),
                    ),
                    loading: () => _PlanningHeader(
                      isCompact: isCompact,
                      projectName: null,
                    ),
                    error: (_, __) => _PlanningHeader(
                      isCompact: isCompact,
                      projectName: null,
                      unavailable: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanningFilters(
                    isCompact: isCompact,
                    searchController: searchController,
                    statusFilter: statusFilter,
                    priorityFilter: priorityFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onStatusChanged: (value) {
                      if (value != null) {
                        setState(() => statusFilter = value);
                      }
                    },
                    onPriorityChanged: (value) {
                      if (value != null) {
                        setState(() => priorityFilter = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        activeTasksAsync.when(
                          data: (tasks) {
                            if (currentProject != null) {
                              _schedulePlanningNotifications(
                                projectName: currentProject.name,
                                tasks: tasks,
                              );
                            }

                            return dependenciesAsync.when(
                              data: (dependencies) {
                                final filteredTasks = _applyFilters(tasks);

                                return DefaultTabController(
                                  length: 3,
                                  child: Column(
                                    children: [
                                      TabBar(
                                        isScrollable: true,
                                        tabs: const [
                                          Tab(text: 'Liste'),
                                          Tab(text: 'Gantt'),
                                          Tab(text: 'DÃƒÆ’Ã‚Â©pendances'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: TabBarView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          children: [
                                            _TasksList(
                                              isCompact: isCompact,
                                              tasks: filteredTasks,
                                              onEdit: (task) => _openEditTask(
                                                context,
                                                task: task,
                                              ),
                                              onDelete: (task) =>
                                                  _deleteTask(context, task),
                                              onToggleArchive: _toggleArchive,
                                            ),
                                            GanttView(
                                              tasks: filteredTasks,
                                              dependencies: dependencies,
                                            ),
                                            SingleChildScrollView(
                                              child: TaskDependenciesPanel(
                                                tasks: filteredTasks,
                                                dependencies: dependencies,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (error, _) => Center(
                                child:
                                    Text('Erreur dÃƒÆ’Ã‚Â©pendances: $error'),
                              ),
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                        archivedTasksAsync.when(
                          data: (tasks) => _TasksList(
                            isCompact: isCompact,
                            tasks: _applyFilters(tasks),
                            onEdit: (task) =>
                                _openEditTask(context, task: task),
                            onDelete: (task) => _deleteTask(context, task),
                            onToggleArchive: _toggleArchive,
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Center(child: Text('Erreur: $error')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.isCompact,
    this.projectName,
    this.onPrint,
    this.onCreateTask,
    this.unavailable = false,
  });

  final bool isCompact;
  final String? projectName;
  final VoidCallback? onPrint;
  final VoidCallback? onCreateTask;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final subtitle = unavailable
        ? 'Projet courant indisponible.'
        : projectName == null
            ? 'Chargement projet courant...'
            : 'Projet courant : $projectName';

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onPrint,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF Planning'),
        ),
        ElevatedButton.icon(
          onPressed: onCreateTask,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle tÃƒÆ’Ã‚Â¢che'),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planning projet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle),
                  const SizedBox(height: 12),
                  actions,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planning projet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _PlanningFilters extends StatelessWidget {
  const _PlanningFilters({
    required this.isCompact,
    required this.searchController,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  final bool isCompact;
  final TextEditingController searchController;
  final String statusFilter;
  final String priorityFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isCompact ? double.infinity : 360,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Recherche',
                  hintText: 'Titre, lot, description',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: statusFilter,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: 'tous', child: Text('Tous')),
                  DropdownMenuItem(
                      value: 'brouillon', child: Text('Brouillon')),
                  DropdownMenuItem(
                      value: 'a_faire', child: Text('ÃƒÆ’Ã¢â€šÂ¬ faire')),
                  DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
                  DropdownMenuItem(
                      value: 'bloquee', child: Text('BloquÃƒÆ’Ã‚Â©e')),
                  DropdownMenuItem(
                      value: 'terminee', child: Text('TerminÃƒÆ’Ã‚Â©e')),
                  DropdownMenuItem(
                      value: 'annulee', child: Text('AnnulÃƒÆ’Ã‚Â©e')),
                  DropdownMenuItem(
                      value: 'archivee', child: Text('ArchivÃƒÆ’Ã‚Â©e')),
                ],
                onChanged: onStatusChanged,
              ),
            ),
            SizedBox(
              width: isCompact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: priorityFilter,
                decoration: const InputDecoration(labelText: 'PrioritÃƒÆ’Ã‚Â©'),
                items: const [
                  DropdownMenuItem(value: 'toutes', child: Text('Toutes')),
                  DropdownMenuItem(value: 'basse', child: Text('Basse')),
                  DropdownMenuItem(value: 'normale', child: Text('Normale')),
                  DropdownMenuItem(value: 'haute', child: Text('Haute')),
                  DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                ],
                onChanged: onPriorityChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksList extends StatelessWidget {
  const _TasksList({
    required this.isCompact,
    required this.tasks,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleArchive,
  });

  final bool isCompact;
  final List<ProjectTask> tasks;
  final Future<void> Function(ProjectTask task) onEdit;
  final Future<void> Function(ProjectTask task) onDelete;
  final Future<void> Function(ProjectTask task) onToggleArchive;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucune tÃƒÆ’Ã‚Â¢che.'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final plannedStart = task.plannedStartDate == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(task.plannedStartDate!);
          final plannedEnd = task.plannedEndDate == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(task.plannedEndDate!);

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isCompact) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PriorityChip(priority: task.priority),
                        _StatusChip(status: task.status),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriorityChip(priority: task.priority),
                        const SizedBox(width: 8),
                        _StatusChip(status: task.status),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (isCompact) ...[
                    _InfoLine(label: 'Lot', value: task.lot),
                    const SizedBox(height: 6),
                    _InfoLine(label: 'DÃƒÆ’Ã‚Â©but', value: plannedStart),
                    const SizedBox(height: 6),
                    _InfoLine(label: 'Fin', value: plannedEnd),
                    const SizedBox(height: 6),
                    _InfoLine(
                      label: 'DurÃƒÆ’Ã‚Â©e',
                      value: '${task.plannedDurationDays} jour(s)',
                    ),
                    const SizedBox(height: 6),
                    _InfoLine(
                      label: 'Type',
                      value: task.isMilestone ? 'Jalon' : 'TÃƒÆ’Ã‚Â¢che',
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                            child: _InfoLine(label: 'Lot', value: task.lot)),
                        Expanded(
                          child: _InfoLine(
                              label: 'DÃƒÆ’Ã‚Â©but', value: plannedStart),
                        ),
                        Expanded(
                            child: _InfoLine(label: 'Fin', value: plannedEnd)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoLine(
                            label: 'DurÃƒÆ’Ã‚Â©e',
                            value: '${task.plannedDurationDays} jour(s)',
                          ),
                        ),
                        Expanded(
                          child: _InfoLine(
                            label: 'Type',
                            value: task.isMilestone ? 'Jalon' : 'TÃƒÆ’Ã‚Â¢che',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (task.progress / 100).clamp(0, 1),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${task.progress.toStringAsFixed(0)} %'),
                  ),
                  if (task.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(task.description),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onEdit(task),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                      TextButton.icon(
                        onPressed: () => onToggleArchive(task),
                        icon: Icon(
                          task.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        label: Text(task.isArchived
                            ? 'DÃƒÆ’Ã‚Â©sarchiver'
                            : 'Archiver'),
                      ),
                      TextButton.icon(
                        onPressed: () => onDelete(task),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label : ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
  });

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);

    return Chip(
      label: Text(_priorityLabel(priority)),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'brouillon':
      return Colors.blueGrey;
    case 'a_faire':
      return Colors.indigo;
    case 'en_cours':
      return Colors.orange;
    case 'bloquee':
      return Colors.red;
    case 'terminee':
      return Colors.green;
    case 'annulee':
      return Colors.redAccent;
    case 'archivee':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'basse':
      return Colors.green;
    case 'normale':
      return Colors.blueGrey;
    case 'haute':
      return Colors.orange;
    case 'urgente':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'a_faire':
      return 'ÃƒÆ’Ã¢â€šÂ¬ faire';
    case 'en_cours':
      return 'En cours';
    case 'bloquee':
      return 'BloquÃƒÆ’Ã‚Â©e';
    case 'terminee':
      return 'TerminÃƒÆ’Ã‚Â©e';
    case 'annulee':
      return 'AnnulÃƒÆ’Ã‚Â©e';
    case 'archivee':
      return 'ArchivÃƒÆ’Ã‚Â©e';
    default:
      return status;
  }
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'basse':
      return 'Basse';
    case 'normale':
      return 'Normale';
    case 'haute':
      return 'Haute';
    case 'urgente':
      return 'Urgente';
    default:
      return priority;
  }
}
