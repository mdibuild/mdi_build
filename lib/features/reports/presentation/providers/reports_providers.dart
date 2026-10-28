import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_report.dart';
import '../../../../core/models/project_report_section.dart';
import '../../../../core/models/project_report_source.dart';
import '../../data/reports_repository.dart';
import '../../../projects/presentation/providers/project_scope_provider.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final activeReportsProvider = FutureProvider<List<ProjectReport>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.read(reportsRepositoryProvider).fetchReportsByProject(
            projectId,
            archived: false,
          ));
});

final archivedReportsProvider =
    FutureProvider<List<ProjectReport>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.read(reportsRepositoryProvider).fetchReportsByProject(
            projectId,
            archived: true,
          ));
});

final reportSectionsProvider =
    FutureProvider.family<List<ProjectReportSection>, String>(
        (ref, reportId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportsRepositoryProvider).fetchSections(reportId);
});

final reportSourcesProvider =
    FutureProvider.family<List<ProjectReportSource>, String>(
        (ref, reportId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportsRepositoryProvider).fetchSources(reportId);
});
