import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/project_task.dart';
import '../../../core/models/project_task_dependency.dart';

enum GanttScale {
  day,
  week,
  month,
}

class GanttView extends StatefulWidget {
  const GanttView({
    super.key,
    required this.tasks,
    this.dependencies = const [],
  });

  final List<ProjectTask> tasks;
  final List<ProjectTaskDependency> dependencies;

  @override
  State<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<GanttView> {
  GanttScale scale = GanttScale.week;

  @override
  Widget build(BuildContext context) {
    final datedTasks = widget.tasks
        .where(
          (task) =>
              task.plannedStartDate != null && task.plannedEndDate != null,
        )
        .toList()
      ..sort((a, b) => a.plannedStartDate!.compareTo(b.plannedStartDate!));

    if (widget.tasks.isEmpty) {
      return const _EmptyGanttCard(
        text: 'Aucune tâche à afficher dans le Gantt.',
      );
    }

    if (datedTasks.isEmpty) {
      return const _EmptyGanttCard(
        text: 'Aucune tâche avec dates planifiées.',
      );
    }

    DateTime minDate = _normalizeDate(datedTasks.first.plannedStartDate!);
    DateTime maxDate = _normalizeDate(datedTasks.first.plannedEndDate!);

    for (final task in datedTasks) {
      final start = _normalizeDate(task.plannedStartDate!);
      final end = _normalizeDate(task.plannedEndDate!);

      if (start.isBefore(minDate)) {
        minDate = start;
      }
      if (end.isAfter(maxDate)) {
        maxDate = end;
      }
    }

    minDate = minDate.subtract(const Duration(days: 2));
    maxDate = maxDate.add(const Duration(days: 2));

    final columns = _buildColumns(minDate, maxDate, scale);
    final unitWidth = _unitWidth(scale);
    final timelineWidth = columns.length * unitWidth;

    const rowHeight = 66.0;
    const headerHeight = 56.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final labelWidth = screenWidth < 420 ? 120.0 : 240.0;
    final ganttHeight = math.min(
      360.0,
      math.max(260.0, MediaQuery.of(context).size.height * 0.34),
    );

    final tasksById = {
      for (final task in datedTasks) task.id: task,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diagramme de Gantt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<GanttScale>(
                    segments: const [
                      ButtonSegment<GanttScale>(
                        value: GanttScale.day,
                        label: Text('Jour'),
                      ),
                      ButtonSegment<GanttScale>(
                        value: GanttScale.week,
                        label: Text('Semaine'),
                      ),
                      ButtonSegment<GanttScale>(
                        value: GanttScale.month,
                        label: Text('Mois'),
                      ),
                    ],
                    selected: {scale},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        scale = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: ganttHeight,
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
                        _GanttHeader(
                          labelWidth: labelWidth,
                          headerHeight: headerHeight,
                          timelineWidth: timelineWidth,
                          unitWidth: unitWidth,
                          columns: columns,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TaskLabelsColumn(
                              tasks: datedTasks,
                              labelWidth: labelWidth,
                              rowHeight: rowHeight,
                            ),
                            _TimelineArea(
                              tasks: datedTasks,
                              dependencies: widget.dependencies,
                              tasksById: tasksById,
                              columns: columns,
                              timelineWidth: timelineWidth,
                              unitWidth: unitWidth,
                              rowHeight: rowHeight,
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
        ],
      ),
    );
  }
}

class _EmptyGanttCard extends StatelessWidget {
  const _EmptyGanttCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text),
        ),
      ),
    );
  }
}

class _GanttHeader extends StatelessWidget {
  const _GanttHeader({
    required this.labelWidth,
    required this.headerHeight,
    required this.timelineWidth,
    required this.unitWidth,
    required this.columns,
  });

  final double labelWidth;
  final double headerHeight;
  final double timelineWidth;
  final double unitWidth;
  final List<_GanttColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: labelWidth,
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: const Text(
            'Tâches',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: timelineWidth,
          height: headerHeight,
          child: Row(
            children: [
              for (final column in columns)
                Container(
                  width: unitWidth,
                  height: headerHeight,
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    column.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskLabelsColumn extends StatelessWidget {
  const _TaskLabelsColumn({
    required this.tasks,
    required this.labelWidth,
    required this.rowHeight,
  });

  final List<ProjectTask> tasks;
  final double labelWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: labelWidth,
      child: Column(
        children: [
          for (final task in tasks)
            Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.progress.toStringAsFixed(0)}% âDA¢ ${_statusLabel(task.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineArea extends StatelessWidget {
  const _TimelineArea({
    required this.tasks,
    required this.dependencies,
    required this.tasksById,
    required this.columns,
    required this.timelineWidth,
    required this.unitWidth,
    required this.rowHeight,
  });

  final List<ProjectTask> tasks;
  final List<ProjectTaskDependency> dependencies;
  final Map<String, ProjectTask> tasksById;
  final List<_GanttColumn> columns;
  final double timelineWidth;
  final double unitWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: timelineWidth,
      height: tasks.length * rowHeight,
      child: Stack(
        children: [
          Row(
            children: [
              for (int i = 0; i < columns.length; i++)
                Container(
                  width: unitWidth,
                  height: tasks.length * rowHeight,
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.white
                        : AppColors.surfaceAlt.withValues(alpha: 0.45),
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
            ],
          ),
          Column(
            children: [
              for (int i = 0; i < tasks.length; i++)
                Container(
                  height: rowHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
            ],
          ),
          ...List.generate(tasks.length, (rowIndex) {
            final task = tasks[rowIndex];
            final startIndex = _columnIndexForDate(
              task.plannedStartDate!,
              columns,
            );
            final endIndex = _columnIndexForDate(
              task.plannedEndDate!,
              columns,
            );

            if (startIndex == null || endIndex == null) {
              return const SizedBox.shrink();
            }

            final plannedLeft = startIndex * unitWidth;
            final plannedWidth = math.max(
              (endIndex - startIndex + 1) * unitWidth,
              unitWidth * 0.75,
            );

            final progressWidth =
                plannedWidth * (task.progress / 100).clamp(0.0, 1.0);

            final delayed = task.status != 'terminee' &&
                task.plannedEndDate != null &&
                DateTime.now().isAfter(task.plannedEndDate!);

            final progressColor = delayed
                ? AppColors.danger
                : task.status == 'terminee'
                    ? AppColors.success
                    : AppColors.info;

            return Positioned(
              left: plannedLeft + 4,
              top: rowIndex * rowHeight + 15,
              child: SizedBox(
                width: plannedWidth - 8,
                height: rowHeight - 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: plannedWidth - 8,
                      height: rowHeight - 26,
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(
                          task.isMilestone ? 16 : 10,
                        ),
                      ),
                    ),
                    if (progressWidth > 0)
                      Positioned(
                        left: 0,
                        top: 5,
                        child: Container(
                          width: math.max(18, progressWidth - 8),
                          height: rowHeight - 36,
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(
                              task.isMilestone ? 12 : 8,
                            ),
                          ),
                        ),
                      ),
                    if (task.isMilestone)
                      Positioned(
                        right: -8,
                        top: 6,
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 18,
                            height: 18,
                            color: progressColor,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 5,
                      child: Text(
                        task.isMilestone
                            ? 'Jalon'
                            : (task.lot.trim().isEmpty ? task.title : task.lot),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ..._buildDependencyWidgets(
            tasks: tasks,
            tasksById: tasksById,
            dependencies: dependencies,
            columns: columns,
            unitWidth: unitWidth,
            rowHeight: rowHeight,
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildDependencyWidgets({
  required List<ProjectTask> tasks,
  required Map<String, ProjectTask> tasksById,
  required List<ProjectTaskDependency> dependencies,
  required List<_GanttColumn> columns,
  required double unitWidth,
  required double rowHeight,
}) {
  const lineThickness = 3.0;
  const arrowSize = 14.0;
  final widgets = <Widget>[];

  for (final dependency in dependencies) {
    final predecessor = tasksById[dependency.predecessorTaskId];
    final successor = tasksById[dependency.successorTaskId];

    if (predecessor == null || successor == null) {
      continue;
    }

    final predecessorRow =
        tasks.indexWhere((task) => task.id == predecessor.id);
    final successorRow = tasks.indexWhere((task) => task.id == successor.id);

    if (predecessorRow == -1 || successorRow == -1) {
      continue;
    }

    final predecessorStart =
        _columnIndexForDate(predecessor.plannedStartDate!, columns);
    final predecessorEnd =
        _columnIndexForDate(predecessor.plannedEndDate!, columns);
    final successorStart =
        _columnIndexForDate(successor.plannedStartDate!, columns);
    final successorEnd =
        _columnIndexForDate(successor.plannedEndDate!, columns);

    if (predecessorStart == null ||
        predecessorEnd == null ||
        successorStart == null ||
        successorEnd == null) {
      continue;
    }

    late double startX;
    late double endX;

    switch (dependency.dependencyType) {
      case 'start_to_finish':
        startX = predecessorStart * unitWidth + 8;
        endX = (successorEnd + 1) * unitWidth - 8;
        break;
      case 'start_to_start':
        startX = predecessorStart * unitWidth + 8;
        endX = successorStart * unitWidth + 8;
        break;
      case 'finish_to_finish':
        startX = (predecessorEnd + 1) * unitWidth - 8;
        endX = (successorEnd + 1) * unitWidth - 8;
        break;
      case 'finish_to_start':
      default:
        startX = (predecessorEnd + 1) * unitWidth - 8;
        endX = successorStart * unitWidth + 8;
        break;
    }

    final startY = predecessorRow * rowHeight + (rowHeight / 2);
    final endY = successorRow * rowHeight + (rowHeight / 2);

    final direction = endX >= startX ? 1.0 : -1.0;
    final elbowX = startX + (22 * direction);

    widgets.add(
      Positioned(
        left: math.min(startX, elbowX),
        top: startY - (lineThickness / 2),
        child: Container(
          width: (elbowX - startX).abs().clamp(1, double.infinity),
          height: lineThickness,
          color: AppColors.purple,
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: elbowX - (lineThickness / 2),
        top: math.min(startY, endY),
        child: Container(
          width: lineThickness,
          height: (endY - startY).abs().clamp(1, double.infinity),
          color: AppColors.purple,
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: math.min(elbowX, endX),
        top: endY - (lineThickness / 2),
        child: Container(
          width: (endX - elbowX).abs().clamp(1, double.infinity),
          height: lineThickness,
          color: AppColors.purple,
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: startX - 3,
        top: startY - 3,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.purple,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: direction >= 0 ? endX - arrowSize : endX,
        top: endY - (arrowSize / 2),
        child: Icon(
          direction >= 0 ? Icons.arrow_right : Icons.arrow_left,
          size: arrowSize,
          color: AppColors.purple,
        ),
      ),
    );
  }

  return widgets;
}

class _GanttColumn {
  const _GanttColumn({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

double _unitWidth(GanttScale scale) {
  switch (scale) {
    case GanttScale.day:
      return 54;
    case GanttScale.week:
      return 110;
    case GanttScale.month:
      return 150;
  }
}

List<_GanttColumn> _buildColumns(
  DateTime minDate,
  DateTime maxDate,
  GanttScale scale,
) {
  switch (scale) {
    case GanttScale.day:
      return _buildDayColumns(minDate, maxDate);
    case GanttScale.week:
      return _buildWeekColumns(minDate, maxDate);
    case GanttScale.month:
      return _buildMonthColumns(minDate, maxDate);
  }
}

List<_GanttColumn> _buildDayColumns(DateTime minDate, DateTime maxDate) {
  final columns = <_GanttColumn>[];
  var current = _normalizeDate(minDate);

  while (!current.isAfter(maxDate)) {
    columns.add(
      _GanttColumn(
        start: current,
        end: current,
        label: DateFormat('dd/MM').format(current),
      ),
    );
    current = current.add(const Duration(days: 1));
  }

  return columns;
}

List<_GanttColumn> _buildWeekColumns(DateTime minDate, DateTime maxDate) {
  final columns = <_GanttColumn>[];
  var current = _normalizeDate(minDate);

  while (current.weekday != DateTime.monday) {
    current = current.subtract(const Duration(days: 1));
  }

  while (!current.isAfter(maxDate)) {
    final end = current.add(const Duration(days: 6));
    columns.add(
      _GanttColumn(
        start: current,
        end: end,
        label:
            'S${_weekNumber(current)}\n${DateFormat('MM/yy').format(current)}',
      ),
    );
    current = current.add(const Duration(days: 7));
  }

  return columns;
}

List<_GanttColumn> _buildMonthColumns(DateTime minDate, DateTime maxDate) {
  final columns = <_GanttColumn>[];
  var current = DateTime(minDate.year, minDate.month);

  while (!current.isAfter(maxDate)) {
    final end = DateTime(current.year, current.month + 1, 0);
    columns.add(
      _GanttColumn(
        start: current,
        end: end,
        label: DateFormat('MMM\nyyyy').format(current),
      ),
    );
    current = DateTime(current.year, current.month + 1);
  }

  return columns;
}

int? _columnIndexForDate(DateTime date, List<_GanttColumn> columns) {
  final normalized = _normalizeDate(date);

  for (int i = 0; i < columns.length; i++) {
    final start = _normalizeDate(columns[i].start);
    final end = _normalizeDate(columns[i].end);

    if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
      return i;
    }
  }

  return null;
}

int _weekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday - 1) / 7).floor() + 1;
}

String _statusLabel(String status) {
  switch (status) {
    case 'brouillon':
      return 'Brouillon';
    case 'a_faire':
      return 'ÃDA faire';
    case 'en_cours':
      return 'En cours';
    case 'bloquee':
      return 'Bloquée';
    case 'terminee':
      return 'Terminée';
    case 'annulee':
      return 'Annulée';
    case 'archivee':
      return 'Archivée';
    default:
      return status;
  }
}
