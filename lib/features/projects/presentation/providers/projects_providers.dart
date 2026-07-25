import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project.dart';
import '../../data/projects_repository.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository();
});

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  return ref.watch(projectsRepositoryProvider).fetchProjects();
});
