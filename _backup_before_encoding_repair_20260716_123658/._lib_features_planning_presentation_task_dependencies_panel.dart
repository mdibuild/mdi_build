import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_task.dart';
import '../../../core/models/project_task_dependency.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/planning_providers.dart';

class TaskDependenciesPanel extends ConsumerStatefulWidget {
  const TaskDependenciesPanel({
    super.key,
    required this.tasks,
    required this.dependencies,
  });

  final List<ProjectTask> tasks;
  final List<ProjectTaskDependency> dependencies;

  @override
  ConsumerState<TaskDependenciesPanel> createState() =>
      _TaskDependenciesPanelState();
}

class _TaskDependenciesPanelState extends ConsumerState<TaskDependenciesPanel> {
  String? predecessorTaskId;
  String? successorTaskId;
  String dependencyType = 'finish_to_start';
  bool saving = false;

  Future<void> createDependency() async {
    if (saving) {
      return;
    }

    final project = await ref.read(selectedProjectProvider.future);
    final profile = await ref.read(currentProfileProvider.future);

    if (project == null || profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projet ou profil introuvable.')),
        );
      }
      return;
    }

    if ((predecessorTaskId ?? '').isEmpty || (successorTaskId ?? '').isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis les deux tÃƒÆ’Ã‚Â¢ches.')),
        );
      }
      return;
    }

    if (predecessorTaskId == successorTaskId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Une tÃƒÆ’Ã‚Â¢che ne peut pas dÃƒÆ’Ã‚Â©pendre dÃƒÂ¢DAÃ¢âDAžÂ¢elle-mÃƒÆ’Ã‚Âªme.')),
        );
      }
      return;
    }

    setState(() => saving = true);

    try {
      final dependency = ProjectTaskDependency(
        id: '',
        companyId: profile.companyId,
        projectId: project.id,
        predecessorTaskId: predecessorTaskId!,
        successorTaskId: successorTaskId!,
        dependencyType: dependencyType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(planningRepositoryProvider).createDependency(dependency);

      ref.invalidate(taskDependenciesProvider);

      if (!mounted) {
        return;
      }

      setState(() {
        predecessorTaskId = null;
        successorTaskId = null;
        dependencyType = 'finish_to_start';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DÃƒÆ’Ã‚Â©pendance ajoutÃƒÆ’Ã‚Â©e.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> deleteDependency(ProjectTaskDependency dependency) async {
    await ref.read(planningRepositoryProvider).deleteDependency(dependency.id);
    ref.invalidate(taskDependenciesProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DÃƒÆ’Ã‚Â©pendance supprimÃƒÆ’Ã‚Â©e.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datedTasks = widget.tasks
        .where((task) =>
            task.plannedStartDate != null && task.plannedEndDate != null)
        .toList();

    final taskNamesById = {
      for (final task in widget.tasks) task.id: task.title,
    };

    final taskOptions = datedTasks
        .map(
          (task) => DropdownMenuItem<String>(
            value: task.id,
            child: Text(task.title),
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DÃƒÆ’Ã‚Â©pendances',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seules les tÃƒÆ’Ã‚Â¢ches avec date dÃƒÆ’Ã‚Â©but et date fin apparaissent dans le Gantt.',
              ),
            ),
            const SizedBox(height: 12),
            if (datedTasks.length < 2)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Il faut au moins 2 tÃƒÆ’Ã‚Â¢ches datÃƒÆ’Ã‚Â©es pour crÃƒÆ’Ã‚Â©er une liaison visible.',
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: predecessorTaskId,
                items: taskOptions,
                onChanged: (value) {
                  setState(() => predecessorTaskId = value);
                },
                decoration: const InputDecoration(
                  labelText: 'TÃƒÆ’Ã‚Â¢che source',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: successorTaskId,
                items: taskOptions,
                onChanged: (value) {
                  setState(() => successorTaskId = value);
                },
                decoration: const InputDecoration(
                  labelText: 'TÃƒÆ’Ã‚Â¢che cible',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: dependencyType,
                items: const [
                  DropdownMenuItem(
                    value: 'finish_to_start',
                    child: Text('Fin ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ DÃƒÆ’Ã‚Â©but'),
                  ),
                  DropdownMenuItem(
                    value: 'start_to_finish',
                    child: Text('DÃƒÆ’Ã‚Â©but ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ Fin'),
                  ),
                  DropdownMenuItem(
                    value: 'start_to_start',
                    child: Text('DÃƒÆ’Ã‚Â©but ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ DÃƒÆ’Ã‚Â©but'),
                  ),
                  DropdownMenuItem(
                    value: 'finish_to_finish',
                    child: Text('Fin ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ Fin'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => dependencyType = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Type de liaison',
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : createDependency,
                  icon: const Icon(Icons.link),
                  label: Text(saving
                      ? 'Enregistrement...'
                      : 'Ajouter dÃƒÆ’Ã‚Â©pendance'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (widget.dependencies.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Aucune dÃƒÆ’Ã‚Â©pendance.'),
              )
            else
              ...widget.dependencies.map(
                (dependency) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${taskNamesById[dependency.predecessorTaskId] ?? dependency.predecessorTaskId} ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ ${taskNamesById[dependency.successorTaskId] ?? dependency.successorTaskId}',
                  ),
                  subtitle: Text(_dependencyLabel(dependency.dependencyType)),
                  trailing: IconButton(
                    onPressed: () => deleteDependency(dependency),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dependencyLabel(String value) {
    switch (value) {
      case 'finish_to_start':
        return 'Fin ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ DÃƒÆ’Ã‚Â©but';
      case 'start_to_finish':
        return 'DÃƒÆ’Ã‚Â©but ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ Fin';
      case 'start_to_start':
        return 'DÃƒÆ’Ã‚Â©but ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ DÃƒÆ’Ã‚Â©but';
      case 'finish_to_finish':
        return 'Fin ÃƒÂ¢Ã¢DAÂ Ã¢DAâ„¢ Fin';
      default:
        return value;
    }
  }
}
