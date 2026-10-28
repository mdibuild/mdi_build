import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_task.dart';
import '../../../../core/models/project_task_dependency.dart';
import '../../data/planning_repository.dart';
import '../../../projects/presentation/providers/project_scope_provider.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepository();
});

final activeTasksProvider = FutureProvider<List<ProjectTask>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(planningRepositoryProvider).fetchTasks(
            projectId: projectId,
            archived: false,
          ));
});

final archivedTasksProvider = FutureProvider<List<ProjectTask>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(planningRepositoryProvider).fetchTasks(
            projectId: projectId,
            archived: true,
          ));
});

final taskDependenciesProvider =
    FutureProvider<List<ProjectTaskDependency>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(planningRepositoryProvider).fetchDependencies(
            projectId: projectId,
          ));
});
