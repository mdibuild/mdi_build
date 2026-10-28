import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project.dart';
import 'projects_providers.dart';
import 'selected_project_provider.dart';

/// Portée des modules : le chantier sélectionné (false) ou « Tous les
/// projets » (true, par défaut). Le chantier sélectionné reste mémorisé : il sert aux
/// créations (nouveau devis, nouvelle tâche…) même en vue « tous ».
class ProjectScopeAll extends Notifier<bool> {
  ProjectScopeAll({this.initial = true});

  /// Par défaut, tous les modules affichent tous les projets.
  final bool initial;

  @override
  bool build() => initial;

  void set(bool all) => state = all;
}

final projectScopeAllProvider =
    NotifierProvider<ProjectScopeAll, bool>(ProjectScopeAll.new);

/// Chantiers dont les modules affichent les données.
final scopedProjectsProvider = FutureProvider<List<Project>>((ref) async {
  if (ref.watch(projectScopeAllProvider)) {
    return ref.watch(projectsProvider.future);
  }
  final project = await ref.watch(selectedProjectProvider.future);
  return project == null ? const [] : [project];
});

/// Charge une liste pour chaque chantier de la portée et les réunit.
Future<List<T>> forScopedProjects<T>(
  Ref ref,
  Future<List<T>> Function(String projectId) fetch,
) async {
  final projects = await ref.watch(scopedProjectsProvider.future);
  if (projects.length == 1) {
    return fetch(projects.single.id);
  }
  final lists = await Future.wait([for (final p in projects) fetch(p.id)]);
  return [for (final list in lists) ...list];
}
