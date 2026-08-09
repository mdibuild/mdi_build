import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project.dart';
import '../../../../core/services/project_selection_storage.dart';
import 'projects_providers.dart';

final projectSelectionStorageProvider =
    Provider<ProjectSelectionStorage>((ref) {
  return ProjectSelectionStorage();
});

final selectedProjectIdProvider =
    AsyncNotifierProvider<SelectedProjectIdNotifier, String?>(
  SelectedProjectIdNotifier.new,
);

class SelectedProjectIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return ref.read(projectSelectionStorageProvider).readSelectedProjectId();
  }

  Future<void> setProjectId(String projectId) async {
    await ref
        .read(projectSelectionStorageProvider)
        .writeSelectedProjectId(projectId);
    state = AsyncData(projectId);
  }

  Future<void> clear() async {
    await ref.read(projectSelectionStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final selectedProjectProvider = FutureProvider<Project?>((ref) async {
  final selectedId = await ref.watch(selectedProjectIdProvider.future);
  final projects = await ref.watch(projectsProvider.future);

  if (projects.isEmpty) {
    return null;
  }

  if (selectedId == null) {
    return projects.first;
  }

  for (final project in projects) {
    if (project.id == selectedId) {
      return project;
    }
  }

  return projects.first;
});

final projectByIdProvider =
    FutureProvider.family<Project?, String>((ref, projectId) async {
  final projects = await ref.watch(projectsProvider.future);

  for (final project in projects) {
    if (project.id == projectId) {
      return project;
    }
  }

  return null;
});
