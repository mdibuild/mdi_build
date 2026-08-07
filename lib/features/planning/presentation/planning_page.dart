import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';

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

  void _showTemporaryCreateMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Creation de tache stabilisee visuellement. Reconnexion metier a faire ensuite.',
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
                      onCreateTask: _showTemporaryCreateMessage,
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
                      onCreateTask: _showTemporaryCreateMessage,
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
            _PlanningList(tasks: tasks)
          else if (mode == _PlanningViewMode.gantt)
            _PlanningGantt(tasks: tasks)
          else
            _PlanningDependencies(tasks: tasks),
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
  });

  final List<_PlanningTask> tasks;

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
            child: _TaskCard(task: task),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
  });

  final _PlanningTask task;

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
        ],
      ),
    );
  }
}

class _PlanningGantt extends StatelessWidget {
  const _PlanningGantt({
    required this.tasks,
  });

  final List<_PlanningTask> tasks;

  @override
  Widget build(BuildContext context) {
    final datedTasks = tasks
        .where((task) => task.startDate != null && task.endDate != null)
        .toList()
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

    if (datedTasks.isEmpty) {
      return const _PremiumBox(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucune t\u00e2che dat\u00e9e pour le Gantt.'),
          ),
        ),
      );
    }

    DateTime minDate = _dateOnly(datedTasks.first.startDate!);
    DateTime maxDate = _dateOnly(datedTasks.first.endDate!);

    for (final task in datedTasks) {
      final start = _dateOnly(task.startDate!);
      final end = _dateOnly(task.endDate!);

      if (start.isBefore(minDate)) {
        minDate = start;
      }
      if (end.isAfter(maxDate)) {
        maxDate = end;
      }
    }

    minDate = minDate.subtract(const Duration(days: 2));
    maxDate = maxDate.add(const Duration(days: 2));

    final totalDays = math.max(1, maxDate.difference(minDate).inDays + 1);
    const dayWidth = 34.0;
    const labelWidth = 132.0;
    const rowHeight = 58.0;
    const headerHeight = 44.0;

    final timelineWidth = totalDays * dayWidth;
    final height = math.min(
      380.0,
      math.max(260.0, datedTasks.length * rowHeight + headerHeight + 20),
    );

    return _PremiumBox(
      padding: const EdgeInsets.all(0),
      child: SizedBox(
        height: height,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              thumbVisibility: true,
              notificationPredicate: (_) => true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _GanttHeaderCell(
                          width: labelWidth,
                          height: headerHeight,
                          text: 'T\u00e2ches',
                        ),
                        SizedBox(
                          width: timelineWidth,
                          height: headerHeight,
                          child: Row(
                            children: [
                              for (int i = 0; i < totalDays; i++)
                                _GanttHeaderCell(
                                  width: dayWidth,
                                  height: headerHeight,
                                  text: _shortDate(
                                      minDate.add(Duration(days: i))),
                                  small: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Column(
                            children: [
                              for (final task in datedTasks)
                                Container(
                                  height: rowHeight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      right: BorderSide(
                                          color: Colors.grey.shade300),
                                      bottom: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      task.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: timelineWidth,
                          height: datedTasks.length * rowHeight,
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  for (int i = 0; i < totalDays; i++)
                                    Container(
                                      width: dayWidth,
                                      height: datedTasks.length * rowHeight,
                                      decoration: BoxDecoration(
                                        color: i.isEven
                                            ? Colors.white
                                            : context.palette.surfaceAlt
                                                .withValues(alpha: 0.6),
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              for (int i = 0; i < datedTasks.length; i++)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: i * rowHeight,
                                  child: Container(
                                    height: rowHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              for (int i = 0; i < datedTasks.length; i++)
                                _GanttBar(
                                  task: datedTasks[i],
                                  minDate: minDate,
                                  dayWidth: dayWidth,
                                  rowHeight: rowHeight,
                                  rowIndex: i,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GanttHeaderCell extends StatelessWidget {
  const _GanttHeaderCell({
    required this.width,
    required this.height,
    required this.text,
    this.small = false,
  });

  final double width;
  final double height;
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GanttBar extends StatelessWidget {
  const _GanttBar({
    required this.task,
    required this.minDate,
    required this.dayWidth,
    required this.rowHeight,
    required this.rowIndex,
  });

  final _PlanningTask task;
  final DateTime minDate;
  final double dayWidth;
  final double rowHeight;
  final int rowIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final start = _dateOnly(task.startDate!);
    final end = _dateOnly(task.endDate!);
    final left = start.difference(minDate).inDays * dayWidth;
    final days = math.max(1, end.difference(start).inDays + 1);
    final width = math.max(26.0, days * dayWidth - 6);
    final progressWidth = width * (task.progress / 100).clamp(0.0, 1.0);

    final color = task.progress >= 100
        ? colors.success
        : _isLate(task)
            ? colors.danger
            : colors.info;

    return Positioned(
      left: left + 3,
      top: rowIndex * rowHeight + 15,
      child: SizedBox(
        width: width,
        height: 28,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.yellow,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (progressWidth > 0)
              Container(
                width: math.max(18, progressWidth),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            Positioned.fill(
              child: Center(
                child: Text(
                  '${task.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningDependencies extends StatelessWidget {
  const _PlanningDependencies({
    required this.tasks,
  });

  final List<_PlanningTask> tasks;

  @override
  Widget build(BuildContext context) {
    return _PremiumBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D\u00e9pendances',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vue stabilis\u00e9e. Les liaisons m\u00e9tier pourront \u00eatre rebranch\u00e9es ensuite sans casser le Gantt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (tasks.length < 2)
            const Text(
                'Il faut au moins deux t\u00e2ches pour afficher des liaisons.')
          else
            ...tasks.take(8).map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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

bool _isLate(_PlanningTask task) {
  final end = task.endDate;
  if (end == null || task.progress >= 100) {
    return false;
  }

  return DateTime.now().isAfter(end);
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
