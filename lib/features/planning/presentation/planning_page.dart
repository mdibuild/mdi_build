import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/models/project_task.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/planning_providers.dart';
import 'gantt_view.dart';
import 'task_dependencies_panel.dart';
import 'task_form_page.dart';

enum _PlanningViewMode {
  list,
  gantt,
  dependencies,
}

final _planningTasksProvider =
    FutureProvider.autoDispose<List<_PlanningTask>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);

  if (profile == null || project == null) {
    return const <_PlanningTask>[];
  }

  final client = SupabaseService.client;

  Future<List<dynamic>> loadRows(String table,
      {required bool withOrder}) async {
    if (withOrder) {
      return await client
          .from(table)
          .select()
          .eq('company_id', profile.companyId)
          .eq('project_id', project.id)
          .order('planned_start_date', ascending: true) as List<dynamic>;
    }

    return await client
        .from(table)
        .select()
        .eq('company_id', profile.companyId)
        .eq('project_id', project.id) as List<dynamic>;
  }

  List<dynamic> rows;

  try {
    rows = await loadRows('project_tasks', withOrder: true);
  } catch (_) {
    try {
      rows = await loadRows('project_tasks', withOrder: false);
    } catch (_) {
      try {
        rows = await loadRows('tasks', withOrder: true);
      } catch (_) {
        rows = await loadRows('tasks', withOrder: false);
      }
    }
  }

  return rows
      .whereType<Map>()
      .map((row) => _PlanningTask.fromMap(Map<String, dynamic>.from(row)))
      .toList();
});

class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  final TextEditingController _searchController = TextEditingController();

  _PlanningViewMode _mode = _PlanningViewMode.list;
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PlanningTask> _filterTasks(List<_PlanningTask> tasks) {
    final query = _searchController.text.trim().toLowerCase();

    return tasks.where((task) {
      final textOk = query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.lot.toLowerCase().contains(query) ||
          task.status.toLowerCase().contains(query) ||
          task.priority.toLowerCase().contains(query);

      final statusOk = _statusFilter == 'all' || task.status == _statusFilter;
      final priorityOk =
          _priorityFilter == 'all' || task.priority == _priorityFilter;

      return textOk && statusOk && priorityOk;
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(_planningTasksProvider);
  }

  Future<void> _openTaskForm(BuildContext context, {ProjectTask? task}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskFormPage(task: task)),
    );

    ref.invalidate(_planningTasksProvider);
    ref.invalidate(activeTasksProvider);
    ref.invalidate(archivedTasksProvider);
  }

  Future<ProjectTask?> _fetchFullTask(_PlanningTask task) async {
    final project = await ref.read(selectedProjectProvider.future);
    if (project == null) {
      return null;
    }

    final tasks = await ref.read(planningRepositoryProvider).fetchTasks(
          projectId: project.id,
          archived: task.isArchived,
        );

    for (final full in tasks) {
      if (full.id == task.id) {
        return full;
      }
    }
    return null;
  }

  Future<void> _openEditTask(BuildContext context, _PlanningTask task) async {
    final full = await _fetchFullTask(task);
    if (full == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche introuvable.')),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _openTaskForm(context, task: full);
  }

  Future<void> _deleteTask(BuildContext context, _PlanningTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: Text('Supprimer "${task.title}" ? Cette action est définitive.'),
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

    await ref.read(planningRepositoryProvider).deleteTask(task.id);
    ref.invalidate(_planningTasksProvider);
    ref.invalidate(activeTasksProvider);
    ref.invalidate(archivedTasksProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tâche supprimée.')),
    );
  }

  Future<void> _toggleArchiveTask(
      BuildContext context, _PlanningTask task) async {
    final full = await _fetchFullTask(task);
    if (full == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche introuvable.')),
        );
      }
      return;
    }

    await ref
        .read(planningRepositoryProvider)
        .updateTask(full.copyWith(isArchived: !full.isArchived));
    ref.invalidate(_planningTasksProvider);
    ref.invalidate(activeTasksProvider);
    ref.invalidate(archivedTasksProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          full.isArchived ? 'Tâche désarchivée.' : 'Tâche archivée.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final projectAsync = ref.watch(selectedProjectProvider);
    final tasksAsync = ref.watch(_planningTasksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planning'),
          bottom: TabBar(
            labelColor: colors.yellow,
            unselectedLabelColor: Colors.white70,
            indicatorColor: colors.yellow,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'En cours'),
              Tab(text: 'Archiv\u00e9es'),
            ],
          ),
        ),
        body: projectAsync.when(
          data: (project) {
            final projectName = project?.name ?? 'Projet non selectionne';

            return tasksAsync.when(
              data: (allTasks) {
                final activeTasks = _filterTasks(
                    allTasks.where((task) => !task.isArchived).toList());
                final archivedTasks = _filterTasks(
                    allTasks.where((task) => task.isArchived).toList());

                return TabBarView(
                  children: [
                    _PlanningTabContent(
                      projectName: projectName,
                      tasks: activeTasks,
                      allCount:
                          allTasks.where((task) => !task.isArchived).length,
                      mode: _mode,
                      statusFilter: _statusFilter,
                      priorityFilter: _priorityFilter,
                      searchController: _searchController,
                      onRefresh: _refresh,
                      onCreateTask: () => _openTaskForm(context),
                      onEditTask: (task) => _openEditTask(context, task),
                      onDeleteTask: (task) => _deleteTask(context, task),
                      onToggleArchive: (task) =>
                          _toggleArchiveTask(context, task),
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onStatusChanged: (value) {
                        if (value != null) {
                          setState(() => _statusFilter = value);
                        }
                      },
                      onPriorityChanged: (value) {
                        if (value != null) {
                          setState(() => _priorityFilter = value);
                        }
                      },
                      onSearchChanged: (_) => setState(() {}),
                    ),
                    _PlanningTabContent(
                      projectName: projectName,
                      tasks: archivedTasks,
                      allCount:
                          allTasks.where((task) => task.isArchived).length,
                      mode: _mode,
                      statusFilter: _statusFilter,
                      priorityFilter: _priorityFilter,
                      searchController: _searchController,
                      onRefresh: _refresh,
                      onCreateTask: () => _openTaskForm(context),
                      onEditTask: (task) => _openEditTask(context, task),
                      onDeleteTask: (task) => _deleteTask(context, task),
                      onToggleArchive: (task) =>
                          _toggleArchiveTask(context, task),
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onStatusChanged: (value) {
                        if (value != null) {
                          setState(() => _statusFilter = value);
                        }
                      },
                      onPriorityChanged: (value) {
                        if (value != null) {
                          setState(() => _priorityFilter = value);
                        }
                      },
                      onSearchChanged: (_) => setState(() {}),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Erreur planning : $error'),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Erreur projet : $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanningTabContent extends StatelessWidget {
  const _PlanningTabContent({
    required this.projectName,
    required this.tasks,
    required this.allCount,
    required this.mode,
    required this.statusFilter,
    required this.priorityFilter,
    required this.searchController,
    required this.onRefresh,
    required this.onCreateTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onToggleArchive,
    required this.onModeChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onSearchChanged,
  });

  final String projectName;
  final List<_PlanningTask> tasks;
  final int allCount;
  final _PlanningViewMode mode;
  final String statusFilter;
  final String priorityFilter;
  final TextEditingController searchController;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateTask;
  final ValueChanged<_PlanningTask> onEditTask;
  final ValueChanged<_PlanningTask> onDeleteTask;
  final ValueChanged<_PlanningTask> onToggleArchive;
  final ValueChanged<_PlanningViewMode> onModeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanningHeroCard(
            projectName: projectName,
            onCreateTask: onCreateTask,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 14),
          _PlanningFiltersCard(
            searchController: searchController,
            statusFilter: statusFilter,
            priorityFilter: priorityFilter,
            onStatusChanged: onStatusChanged,
            onPriorityChanged: onPriorityChanged,
            onSearchChanged: onSearchChanged,
          ),
          const SizedBox(height: 14),
          _PlanningModeSelector(
            mode: mode,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: 14),
          _PlanningSummaryCard(
            visibleCount: tasks.length,
            totalCount: allCount,
          ),
          const SizedBox(height: 14),
          if (mode == _PlanningViewMode.list)
            _PlanningList(
              tasks: tasks,
              onEdit: onEditTask,
              onDelete: onDeleteTask,
              onToggleArchive: onToggleArchive,
            )
          else if (mode == _PlanningViewMode.gantt)
            // Même diagramme que les rapports : 7 échelles (jour → année),
            // barres au jour près et flèches de dépendances.
            Consumer(
              builder: (context, ref, _) {
                final active = ref.watch(activeTasksProvider).value ?? const [];
                final archived =
                    ref.watch(archivedTasksProvider).value ?? const [];
                final deps =
                    ref.watch(taskDependenciesProvider).value ?? const [];
                final byId = {
                  for (final t in [...active, ...archived]) t.id: t,
                };
                // Mêmes tâches (et même ordre) que la liste affichée.
                final shown = [
                  for (final t in tasks)
                    if (byId[t.id] != null) byId[t.id]!,
                ];
                if (shown.isEmpty && tasks.isNotEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return GanttView(tasks: shown, dependencies: deps);
              },
            )
          else
            Consumer(
              builder: (context, ref, _) {
                final realTasksAsync = ref.watch(activeTasksProvider);
                final depsAsync = ref.watch(taskDependenciesProvider);

                return realTasksAsync.when(
                  data: (realTasks) => depsAsync.when(
                    data: (deps) => TaskDependenciesPanel(
                      tasks: realTasks,
                      dependencies: deps,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Text('Erreur dépendances : $error'),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Erreur tâches : $error'),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PlanningHeroCard extends StatelessWidget {
  const _PlanningHeroCard({
    required this.projectName,
    required this.onCreateTask,
    required this.onRefresh,
  });

  final String projectName;
  final VoidCallback onCreateTask;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PremiumBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planning projet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Projet courant : $projectName',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle t\u00e2che'),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningFiltersCard extends StatelessWidget {
  const _PlanningFiltersCard({
    required this.searchController,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final String priorityFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return _PremiumBox(
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Recherche',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tous')),
              DropdownMenuItem(value: 'a_faire', child: Text('\u00c0 faire')),
              DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
              DropdownMenuItem(value: 'bloquee', child: Text('Bloqu\u00e9e')),
              DropdownMenuItem(value: 'terminee', child: Text('Termin\u00e9e')),
            ],
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: priorityFilter,
            decoration: const InputDecoration(labelText: 'Priorit\u00e9'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Toutes')),
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: onPriorityChanged,
          ),
        ],
      ),
    );
  }
}

class _PlanningModeSelector extends StatelessWidget {
  const _PlanningModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _PlanningViewMode mode;
  final ValueChanged<_PlanningViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PremiumBox(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_PlanningViewMode>(
          selected: {mode},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            onChanged(selection.first);
          },
          segments: const [
            ButtonSegment(
              value: _PlanningViewMode.list,
              label: Text('Liste'),
              icon: Icon(Icons.list_alt_outlined),
            ),
            ButtonSegment(
              value: _PlanningViewMode.gantt,
              label: Text('Gantt'),
              icon: Icon(Icons.view_timeline_outlined),
            ),
            ButtonSegment(
              value: _PlanningViewMode.dependencies,
              label: Text('D\u00e9pendances'),
              icon: Icon(Icons.account_tree_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningSummaryCard extends StatelessWidget {
  const _PlanningSummaryCard({
    required this.visibleCount,
    required this.totalCount,
  });

  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return _PremiumBox(
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: context.palette.petrol),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$visibleCount t\u00e2che(s) affich\u00e9e(s) sur $totalCount',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningList extends StatelessWidget {
  const _PlanningList({
    required this.tasks,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleArchive,
  });

  final List<_PlanningTask> tasks;
  final ValueChanged<_PlanningTask> onEdit;
  final ValueChanged<_PlanningTask> onDelete;
  final ValueChanged<_PlanningTask> onToggleArchive;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _PremiumBox(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucune t\u00e2che pour ce filtre.'),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              task: task,
              onEdit: () => onEdit(task),
              onDelete: () => onDelete(task),
              onToggleArchive: () => onToggleArchive(task),
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleArchive,
  });

  final _PlanningTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return _PremiumBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _Badge(
                label: _statusLabel(task.status),
                color: _statusColor(colors, task.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.lot.isEmpty ? 'Lot non renseign\u00e9' : task.lot,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (task.progress / 100).clamp(0.0, 1.0),
              minHeight: 10,
              color: task.progress >= 100 ? colors.success : colors.petrol,
              backgroundColor: colors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${task.progress.toStringAsFixed(0)}% - ${_dateRangeLabel(task)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
              OutlinedButton.icon(
                onPressed: onToggleArchive,
                icon: Icon(
                  task.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 18,
                ),
                label: Text(task.isArchived ? 'D\u00e9sarchiver' : 'Archiver'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: colors.danger),
                label: Text(
                  'Supprimer',
                  style: TextStyle(color: colors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumBox extends StatelessWidget {
  const _PremiumBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return PremiumSurfaceCard(
      padding: padding,
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumStatusBadge(
      label: label,
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundColor: color,
    );
  }
}

class _PlanningTask {
  const _PlanningTask({
    required this.id,
    required this.title,
    required this.lot,
    required this.status,
    required this.priority,
    required this.progress,
    required this.startDate,
    required this.endDate,
    required this.isArchived,
  });

  final String id;
  final String title;
  final String lot;
  final String status;
  final String priority;
  final double progress;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isArchived;

  factory _PlanningTask.fromMap(Map<String, dynamic> map) {
    final status = _stringValue(map['status'], fallback: 'en_cours');
    final rawArchived = map['is_archived'] ?? map['archived'];

    return _PlanningTask(
      id: _stringValue(map['id'], fallback: ''),
      title: _stringValue(
        map['title'] ?? map['name'] ?? map['task_name'],
        fallback: 'T\u00e2che',
      ),
      lot: _stringValue(map['lot'] ?? map['category'], fallback: ''),
      status: status,
      priority: _stringValue(map['priority'], fallback: 'normal'),
      progress: _progressValue(map['progress'] ?? map['completion']),
      startDate: _dateValue(
        map['planned_start_date'] ?? map['start_date'] ?? map['date_start'],
      ),
      endDate: _dateValue(
        map['planned_end_date'] ?? map['end_date'] ?? map['date_end'],
      ),
      isArchived:
          rawArchived == true || status.toLowerCase().contains('archive'),
    );
  }
}

String _stringValue(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _progressValue(dynamic value) {
  if (value is num) {
    final raw = value.toDouble();
    return raw <= 1 ? (raw * 100).clamp(0, 100) : raw.clamp(0, 100);
  }

  final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
  return parsed <= 1 ? (parsed * 100).clamp(0, 100) : parsed.clamp(0, 100);
}

DateTime? _dateValue(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

String _statusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'a_faire':
      return '\u00c0 faire';
    case 'en_cours':
      return 'En cours';
    case 'bloquee':
      return 'Bloqu\u00e9e';
    case 'terminee':
      return 'Termin\u00e9e';
    case 'annulee':
      return 'Annul\u00e9e';
    case 'archivee':
      return 'Archiv\u00e9e';
    default:
      return status;
  }
}

Color _statusColor(AppPaletteColors colors, String status) {
  switch (status) {
    case 'terminee':
      return colors.success;
    case 'bloquee':
      return colors.danger;
    case 'en_cours':
      return colors.info;
    case 'a_faire':
      return colors.petrol;
    default:
      return colors.textSoft;
  }
}

String _dateRangeLabel(_PlanningTask task) {
  final start = task.startDate;
  final end = task.endDate;

  if (start == null && end == null) {
    return 'Dates non planifi\u00e9es';
  }

  if (start == null) {
    return 'Fin : ${_shortDate(end!)}';
  }

  if (end == null) {
    return 'D\u00e9but : ${_shortDate(start)}';
  }

  return '${_shortDate(start)} - ${_shortDate(end)}';
}

String _shortDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}
