import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_report.dart';
import '../../../../core/models/project_report_section.dart';
import '../../../../core/models/project_report_source.dart';
import '../../data/reports_repository.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final activeReportsProvider = FutureProvider<List<ProjectReport>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return const [];
  }

  return ref.read(reportsRepositoryProvider).fetchReportsByProject(
        project.id,
        archived: false,
      );
});

final archivedReportsProvider =
    FutureProvider<List<ProjectReport>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return const [];
  }

  return ref.read(reportsRepositoryProvider).fetchReportsByProject(
        project.id,
        archived: true,
      );
});

final reportSectionsProvider =
    FutureProvider.family<List<ProjectReportSection>, String>(
        (ref, reportId) async {
  return ref.read(reportsRepositoryProvider).fetchSections(reportId);
});

final reportSourcesProvider =
    FutureProvider.family<List<ProjectReportSource>, String>(
        (ref, reportId) async {
  return ref.read(reportsRepositoryProvider).fetchSources(reportId);
});
