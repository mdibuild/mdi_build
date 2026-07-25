import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_report.dart';
import '../../../core/models/project_report_section.dart';
import '../../../core/models/project_report_source.dart';
import '../../../core/services/supabase_service.dart';
import '../data/reports_repository.dart';
import 'report_generation_service.dart';

class ReportDashboardGenerationService {
  ReportDashboardGenerationService({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<ProjectReport> generateAutomaticReport({
    required ReportsRepository reportsRepository,
    required String companyId,
    required String projectId,
    required String projectName,
    required String? authorId,
    required String sourceModule,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final payload = await _buildPayload(
      companyId: companyId,
      projectId: projectId,
      projectName: projectName,
      sourceModule: sourceModule,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    final generationService = ReportGenerationService();

    return generationService.generateAutomaticReport(
      repository: reportsRepository,
      companyId: companyId,
      projectId: projectId,
      title: _buildTitle(
        sourceModule: sourceModule,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      sourceModule: sourceModule,
      authorId: authorId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      sections: payload.sections,
      sources: payload.sources,
      progressSummary: payload.progressSummary,
      blockers: '',
      decisions: '',
      nextSteps: '',
    );
  }

  Future<_ReportPayload> _buildPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required String sourceModule,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    switch (sourceModule) {
      case 'project':
        return _buildProjectPayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      case 'planning':
        return _buildPlanningPayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      case 'devis':
        return _buildQuotesPayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      case 'achats':
        return _buildPurchasesPayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      case 'metrage':
        return _buildMetragePayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      case 'global':
      default:
        return _buildGlobalPayload(
          companyId: companyId,
          projectId: projectId,
          projectName: projectName,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
    }
  }

  Future<_ReportPayload> _buildGlobalPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final parts = await Future.wait<_ReportPayload>([
      _buildProjectPayload(
        companyId: companyId,
        projectId: projectId,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      _buildPlanningPayload(
        companyId: companyId,
        projectId: projectId,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      _buildQuotesPayload(
        companyId: companyId,
        projectId: projectId,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      _buildPurchasesPayload(
        companyId: companyId,
        projectId: projectId,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      _buildMetragePayload(
        companyId: companyId,
        projectId: projectId,
        projectName: projectName,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
    ]);

    final sections = <ProjectReportSection>[];
    final sources = <ProjectReportSource>[];

    var sortOrder = 10;
    for (final part in parts) {
      for (final section in part.sections) {
        sections.add(
          section.copyWithForGeneration(sortOrder: sortOrder),
        );
        sortOrder += 10;
      }
      sources.addAll(part.sources);
    }

    sections.add(
      _textSection(
        companyId: companyId,
        sectionKey: 'free_notes',
        sectionTitle: 'Compléments manuels',
        sortOrder: sortOrder,
        contentText: '',
        isAutoGenerated: false,
      ),
    );

    return _ReportPayload(
      progressSummary:
          'Rapport global généré pour ${_date(periodStart)} au ${_date(periodEnd)}.',
      sections: sections,
      sources: sources,
    );
  }

  Future<_ReportPayload> _buildProjectPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final rows = await _fetchFirstWorkingTable(
      tables: const ['projects'],
      projectId: projectId,
      orderBy: 'updated_at',
    );

    final project = rows.isNotEmpty ? rows.first : <String, dynamic>{};

    final section = _textSection(
      companyId: companyId,
      sectionKey: 'project_summary',
      sectionTitle: 'Synthèse projet',
      sortOrder: 10,
      contentText: [
        'Projet : $projectName',
        'Période : ${_date(periodStart)} au ${_date(periodEnd)}',
        'Statut : ${project['status'] ?? '-'}',
        'Client : ${project['client_name'] ?? project['client'] ?? '-'}',
        'Dernière mise à jour : ${_safeDateTime(project['updated_at'])}',
      ].join('\n'),
      contentJson: <String, dynamic>{
        'project': project,
      },
      isAutoGenerated: true,
    );

    final source = _source(
      companyId: companyId,
      moduleName: 'project',
      sourceEntityType: 'project',
      sourceEntityId: project['id']?.toString(),
      snapshotJson: <String, dynamic>{
        'project': project,
      },
    );

    return _ReportPayload(
      progressSummary: 'Synthèse projet disponible.',
      sections: [section],
      sources: [source],
    );
  }

  Future<_ReportPayload> _buildPlanningPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final tasks = await _fetchFirstWorkingTable(
      tables: const ['tasks', 'planning_tasks'],
      projectId: projectId,
      orderBy: 'updated_at',
    );

    final done = tasks.where((row) => _statusOf(row) == 'done').length;
    final inProgress =
        tasks.where((row) => _statusOf(row) == 'in_progress').length;
    final late = tasks.where((row) => _statusOf(row) == 'late').length;
    final todo = tasks.where((row) => _statusOf(row) == 'todo').length;

    final section = _textSection(
      companyId: companyId,
      sectionKey: 'planning_summary',
      sectionTitle: 'Synthèse planning',
      sortOrder: 10,
      contentText: [
        'Projet : $projectName',
        'Période : ${_date(periodStart)} au ${_date(periodEnd)}',
        'Total tâches : ${tasks.length}',
        'ÃDA faire : $todo',
        'En cours : $inProgress',
        'Terminées : $done',
        'En retard : $late',
      ].join('\n'),
      contentJson: <String, dynamic>{
        'total': tasks.length,
        'todo': todo,
        'in_progress': inProgress,
        'done': done,
        'late': late,
      },
      isAutoGenerated: true,
    );

    final source = _source(
      companyId: companyId,
      moduleName: 'planning',
      sourceEntityType: 'task_list',
      snapshotJson: <String, dynamic>{
        'count': tasks.length,
        'items': tasks,
      },
    );

    return _ReportPayload(
      progressSummary:
          'Synthèse planning générée sur ${tasks.length} tâche(s).',
      sections: [section],
      sources: [source],
    );
  }

  Future<_ReportPayload> _buildQuotesPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final quotes = await _fetchFirstWorkingTable(
      tables: const ['project_quotes'],
      projectId: projectId,
      orderBy: 'updated_at',
    );

    final draft = quotes
        .where((row) => _stringValue(row['status']) == 'brouillon')
        .length;
    final sent =
        quotes.where((row) => _stringValue(row['status']) == 'envoye').length;
    final signed =
        quotes.where((row) => _stringValue(row['status']) == 'signe').length;
    final last = quotes.isNotEmpty ? quotes.first : <String, dynamic>{};

    final section = _textSection(
      companyId: companyId,
      sectionKey: 'quotes_summary',
      sectionTitle: 'Synthèse devis',
      sortOrder: 10,
      contentText: [
        'Projet : $projectName',
        'Période : ${_date(periodStart)} au ${_date(periodEnd)}',
        'Total devis : ${quotes.length}',
        'Brouillons : $draft',
        'Envoyés : $sent',
        'Signés : $signed',
        'Dernier statut : ${last['status'] ?? '-'}',
        'PU murs : ${_safeNum(last['unit_price_walls'])}',
        'PU plafond : ${_safeNum(last['unit_price_ceiling'])}',
      ].join('\n'),
      contentJson: <String, dynamic>{
        'total': quotes.length,
        'draft': draft,
        'sent': sent,
        'signed': signed,
        'last_quote': last,
      },
      isAutoGenerated: true,
    );

    final source = _source(
      companyId: companyId,
      moduleName: 'devis',
      sourceEntityType: 'quote_list',
      sourceEntityId: last['id']?.toString(),
      snapshotJson: <String, dynamic>{
        'count': quotes.length,
        'items': quotes,
      },
    );

    return _ReportPayload(
      progressSummary: 'Synthèse devis générée sur ${quotes.length} devis.',
      sections: [section],
      sources: [source],
    );
  }

  Future<_ReportPayload> _buildPurchasesPayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final purchases = await _fetchFirstWorkingTable(
      tables: const ['purchases', 'project_purchases'],
      projectId: projectId,
      orderBy: 'updated_at',
    );

    final draft = purchases
        .where((row) => _stringValue(row['status']) == 'brouillon')
        .length;
    final ordered = purchases
        .where((row) => _stringValue(row['status']) == 'commande')
        .length;
    final delivered =
        purchases.where((row) => _stringValue(row['status']) == 'livre').length;

    final totalAmount = purchases.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['total_amount'] ?? row['total'] ?? 0),
    );

    final section = _textSection(
      companyId: companyId,
      sectionKey: 'purchases_summary',
      sectionTitle: 'Synthèse achats',
      sortOrder: 10,
      contentText: [
        'Projet : $projectName',
        'Période : ${_date(periodStart)} au ${_date(periodEnd)}',
        'Total achats : ${purchases.length}',
        'Brouillons : $draft',
        'Commandés : $ordered',
        'Livrés : $delivered',
        'Montant total estimé : ${totalAmount.toStringAsFixed(2)}',
      ].join('\n'),
      contentJson: <String, dynamic>{
        'total': purchases.length,
        'draft': draft,
        'ordered': ordered,
        'delivered': delivered,
        'total_amount': totalAmount,
      },
      isAutoGenerated: true,
    );

    final source = _source(
      companyId: companyId,
      moduleName: 'achats',
      sourceEntityType: 'purchase_list',
      snapshotJson: <String, dynamic>{
        'count': purchases.length,
        'items': purchases,
      },
    );

    return _ReportPayload(
      progressSummary:
          'Synthèse achats générée sur ${purchases.length} achat(s).',
      sections: [section],
      sources: [source],
    );
  }

  Future<_ReportPayload> _buildMetragePayload({
    required String companyId,
    required String projectId,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final spaces = await _fetchFirstWorkingTable(
      tables: const ['spaces', 'project_spaces'],
      projectId: projectId,
      orderBy: 'updated_at',
    );

    final totalCeiling = spaces.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['ceiling_area'] ?? 0),
    );

    final totalWalls = spaces.fold<double>(
      0,
      (sum, row) =>
          sum + _toDouble(row['net_wall_area'] ?? row['wall_area'] ?? 0),
    );

    final section = _textSection(
      companyId: companyId,
      sectionKey: 'metrage_summary',
      sectionTitle: 'Synthèse métré',
      sortOrder: 10,
      contentText: [
        'Projet : $projectName',
        'Période : ${_date(periodStart)} au ${_date(periodEnd)}',
        'Espaces : ${spaces.length}',
        'Surface murs : ${totalWalls.toStringAsFixed(2)}',
        'Surface plafonds : ${totalCeiling.toStringAsFixed(2)}',
      ].join('\n'),
      contentJson: <String, dynamic>{
        'spaces_count': spaces.length,
        'total_walls': totalWalls,
        'total_ceiling': totalCeiling,
      },
      isAutoGenerated: true,
    );

    final source = _source(
      companyId: companyId,
      moduleName: 'metrage',
      sourceEntityType: 'space_list',
      snapshotJson: <String, dynamic>{
        'count': spaces.length,
        'items': spaces,
      },
    );

    return _ReportPayload(
      progressSummary: 'Synthèse métré générée sur ${spaces.length} espace(s).',
      sections: [section],
      sources: [source],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFirstWorkingTable({
    required List<String> tables,
    required String projectId,
    required String orderBy,
  }) async {
    for (final table in tables) {
      try {
        final rows = await _client
            .from(table)
            .select()
            .eq('project_id', projectId)
            .order(orderBy, ascending: false);

        return (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } catch (_) {}
    }

    return const <Map<String, dynamic>>[];
  }

  ProjectReportSection _textSection({
    required String companyId,
    required String sectionKey,
    required String sectionTitle,
    required int sortOrder,
    required String contentText,
    Map<String, dynamic> contentJson = const <String, dynamic>{},
    required bool isAutoGenerated,
  }) {
    final now = DateTime.now();

    return ProjectReportSection(
      id: '',
      companyId: companyId,
      reportId: '',
      sectionKey: sectionKey,
      sectionTitle: sectionTitle,
      sectionType: 'text',
      sortOrder: sortOrder,
      contentText: contentText,
      contentJson: contentJson,
      isAutoGenerated: isAutoGenerated,
      createdAt: now,
      updatedAt: now,
    );
  }

  ProjectReportSource _source({
    required String companyId,
    required String moduleName,
    required String sourceEntityType,
    String? sourceEntityId,
    required Map<String, dynamic> snapshotJson,
  }) {
    final now = DateTime.now();

    return ProjectReportSource(
      id: '',
      companyId: companyId,
      reportId: '',
      moduleName: moduleName,
      sourceEntityType: sourceEntityType,
      sourceEntityId: sourceEntityId,
      snapshotJson: snapshotJson,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _buildTitle({
    required String sourceModule,
    required String projectName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final label = sourceModule == 'global' ? 'global' : sourceModule;
    return 'Rapport $label - $projectName - ${_date(periodStart)} au ${_date(periodEnd)}';
  }

  String _statusOf(Map<String, dynamic> row) {
    final value = _stringValue(row['status']).toLowerCase();

    if (value.contains('retard')) {
      return 'late';
    }
    if (value.contains('cours')) {
      return 'in_progress';
    }
    if (value.contains('term') || value.contains('done')) {
      return 'done';
    }
    return 'todo';
  }

  String _safeDateTime(dynamic value) {
    if (value == null) {
      return '-';
    }
    return value.toString();
  }

  String _safeNum(dynamic value) {
    return _toDouble(value).toStringAsFixed(2);
  }

  String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }
}

class _ReportPayload {
  const _ReportPayload({
    required this.progressSummary,
    required this.sections,
    required this.sources,
  });

  final String progressSummary;
  final List<ProjectReportSection> sections;
  final List<ProjectReportSource> sources;
}

extension on ProjectReportSection {
  ProjectReportSection copyWithForGeneration({
    required int sortOrder,
  }) {
    return ProjectReportSection(
      id: id,
      companyId: companyId,
      reportId: reportId,
      sectionKey: sectionKey,
      sectionTitle: sectionTitle,
      sectionType: sectionType,
      sortOrder: sortOrder,
      contentText: contentText,
      contentJson: contentJson,
      isAutoGenerated: isAutoGenerated,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
