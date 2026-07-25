import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/dashboard_metrics.dart';
import '../../../core/services/supabase_service.dart';

class DashboardMetricsService {
  DashboardMetricsService({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<DashboardMetrics> fetch({
    required String companyId,
    String? projectId,
  }) async {
    final projects = await _fetchRows(
      tableNames: const ['projects'],
      companyId: companyId,
      projectId: null,
      orderBy: 'updated_at',
    );

    final tasks = projectId == null
        ? const <Map<String, dynamic>>[]
        : await _fetchRows(
            tableNames: const ['tasks', 'planning_tasks'],
            companyId: null,
            projectId: projectId,
            orderBy: 'updated_at',
          );

    final quotes = projectId == null
        ? const <Map<String, dynamic>>[]
        : await _fetchRows(
            tableNames: const ['project_quotes'],
            companyId: null,
            projectId: projectId,
            orderBy: 'updated_at',
          );

    final purchases = projectId == null
        ? const <Map<String, dynamic>>[]
        : await _fetchRows(
            tableNames: const ['purchases', 'project_purchases'],
            companyId: null,
            projectId: projectId,
            orderBy: 'updated_at',
          );

    final reports = projectId == null
        ? const <Map<String, dynamic>>[]
        : await _fetchRows(
            tableNames: const ['project_reports'],
            companyId: null,
            projectId: projectId,
            orderBy: 'created_at',
          );

    final documents = projectId == null
        ? const <Map<String, dynamic>>[]
        : await _fetchRows(
            tableNames: const ['project_documents'],
            companyId: null,
            projectId: projectId,
            orderBy: 'created_at',
          );

    final doneTasks = tasks.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      return status.contains('done') || status.contains('term');
    }).length;

    final lateTasks = tasks.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      return status.contains('late') || status.contains('retard');
    }).length;

    final autoReports = reports.where((row) {
      final type = (row['report_type'] ?? 'manual').toString();
      return type != 'manual';
    }).length;

    final manualReports = reports.length - autoReports;

    final recentReportTitles = reports
        .take(4)
        .map((row) => (row['title'] ?? 'Rapport').toString())
        .toList();

    final highlights = <String>[
      if (projects.isNotEmpty) '${projects.length} projet(s) suivis',
      if (tasks.isNotEmpty)
        '$doneTasks tÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â¢che(s) terminÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â©e(s)',
      if (lateTasks > 0)
        '$lateTasks tÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â¢che(s) en retard',
      if (quotes.isNotEmpty) '${quotes.length} devis disponibles',
      if (purchases.isNotEmpty) '${purchases.length} achat(s) suivis',
      if (reports.isNotEmpty)
        '${reports.length} rapport(s) dÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â©jÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â  crÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â©ÃƒÆ’Ã†âDA™ÃƒâDA Ã¢DAâ„¢ÃƒÆ’Ã¢DAÅ¡ÃƒâDAšÃ‚Â©(s)',
    ];

    return DashboardMetrics(
      projectsCount: projects.length,
      tasksCount: tasks.length,
      doneTasksCount: doneTasks,
      lateTasksCount: lateTasks,
      quotesCount: quotes.length,
      purchasesCount: purchases.length,
      reportsCount: reports.length,
      documentsCount: documents.length,
      autoReportsCount: autoReports,
      manualReportsCount: manualReports,
      recentReportTitles: recentReportTitles,
      highlights: highlights,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRows({
    required List<String> tableNames,
    String? companyId,
    String? projectId,
    required String orderBy,
  }) async {
    for (final table in tableNames) {
      try {
        dynamic query = _client.from(table).select();

        if (companyId != null) {
          query = query.eq('company_id', companyId);
        }
        if (projectId != null) {
          query = query.eq('project_id', projectId);
        }

        final rows = await query.order(orderBy, ascending: false);

        return (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } catch (_) {}
    }

    return const <Map<String, dynamic>>[];
  }
}
