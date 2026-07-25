import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_task.dart';
import '../../../../core/models/project_task_dependency.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../data/planning_repository.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepository();
});

final activeTasksProvider = FutureProvider<List<ProjectTask>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(planningRepositoryProvider).fetchTasks(
        projectId: project.id,
        archived: false,
      );
});

final archivedTasksProvider = FutureProvider<List<ProjectTask>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(planningRepositoryProvider).fetchTasks(
        projectId: project.id,
        archived: true,
      );
});

final taskDependenciesProvider =
    FutureProvider<List<ProjectTaskDependency>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(planningRepositoryProvider).fetchDependencies(
        projectId: project.id,
      );
});
