import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_report.dart';
import '../../../core/models/project_report_section.dart';
import '../../../core/models/project_report_source.dart';
import '../../../core/services/supabase_service.dart';

class ReportsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ProjectReport>> fetchReportsByProject(
    String projectId, {
    required bool archived,
  }) async {
    final rows = await _client
        .from('project_reports')
        .select()
        .eq('project_id', projectId)
        .eq('is_archived', archived)
        .order('report_date', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => ProjectReport.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectReport> createReport(ProjectReport report) async {
    final row = await _client
        .from('project_reports')
        .insert(report.toInsertMap())
        .select()
        .single();

    return ProjectReport.fromMap(row);
  }

  Future<ProjectReport> updateReport(ProjectReport report) async {
    final row = await _client
        .from('project_reports')
        .update(report.toUpdateMap())
        .eq('id', report.id)
        .select()
        .single();

    return ProjectReport.fromMap(row);
  }

  Future<void> setArchived({
    required String reportId,
    required bool archived,
  }) async {
    await _client.from('project_reports').update({
      'is_archived': archived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> deleteReport(String reportId) async {
    await _client.from('project_reports').delete().eq('id', reportId);
  }

  Future<List<ProjectReportSection>> fetchSections(String reportId) async {
    final rows = await _client
        .from('project_report_sections')
        .select()
        .eq('report_id', reportId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => ProjectReportSection.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> replaceSections({
    required String reportId,
    required List<ProjectReportSection> sections,
  }) async {
    await _client
        .from('project_report_sections')
        .delete()
        .eq('report_id', reportId);

    if (sections.isEmpty) {
      return;
    }

    await _client.from('project_report_sections').insert(
          sections.map((section) => section.toInsertMap()).toList(),
        );
  }

  Future<List<ProjectReportSource>> fetchSources(String reportId) async {
    final rows = await _client
        .from('project_report_sources')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => ProjectReportSource.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> replaceSources({
    required String reportId,
    required List<ProjectReportSource> sources,
  }) async {
    await _client
        .from('project_report_sources')
        .delete()
        .eq('report_id', reportId);

    if (sources.isEmpty) {
      return;
    }

    await _client.from('project_report_sources').insert(
          sources.map((source) => source.toInsertMap()).toList(),
        );
  }
}
