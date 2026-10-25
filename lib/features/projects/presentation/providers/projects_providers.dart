import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project.dart';
import '../../data/projects_repository.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository();
});

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.watch(projectsRepositoryProvider).fetchProjects();
});
