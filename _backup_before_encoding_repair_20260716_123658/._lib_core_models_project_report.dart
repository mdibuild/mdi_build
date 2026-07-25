import 'package:equatable/equatable.dart';

class ProjectReport extends Equatable {
  const ProjectReport({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.title,
    required this.reportDate,
    required this.weather,
    required this.progressSummary,
    required this.blockers,
    required this.decisions,
    required this.nextSteps,
    required this.authorId,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.reportType = 'manual',
    this.sourceModule = 'global',
    this.status = 'draft',
    this.periodStart,
    this.periodEnd,
    this.generatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String title;
  final DateTime reportDate;
  final String weather;
  final String progressSummary;
  final String blockers;
  final String decisions;
  final String nextSteps;
  final String? authorId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String reportType;
  final String sourceModule;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? generatedAt;

  factory ProjectReport.fromMap(Map<String, dynamic> map) {
    return ProjectReport(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      title: (map['title'] as String?) ?? '',
      reportDate: DateTime.parse(map['report_date'] as String),
      weather: (map['weather'] as String?) ?? '',
      progressSummary: (map['progress_summary'] as String?) ?? '',
      blockers: (map['blockers'] as String?) ?? '',
      decisions: (map['decisions'] as String?) ?? '',
      nextSteps: (map['next_steps'] as String?) ?? '',
      authorId: map['author_id'] as String?,
      isArchived: (map['is_archived'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      reportType: (map['report_type'] as String?) ?? 'manual',
      sourceModule: (map['source_module'] as String?) ?? 'global',
      status: (map['status'] as String?) ?? 'draft',
      periodStart: map['period_start'] == null
          ? null
          : DateTime.parse(map['period_start'] as String),
      periodEnd: map['period_end'] == null
          ? null
          : DateTime.parse(map['period_end'] as String),
      generatedAt: map['generated_at'] == null
          ? null
          : DateTime.parse(map['generated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'project_id': projectId,
      'title': title,
      'report_date': _dateOnly(reportDate),
      'weather': weather,
      'progress_summary': progressSummary,
      'blockers': blockers,
      'decisions': decisions,
      'next_steps': nextSteps,
      'author_id': authorId,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'report_type': reportType,
      'source_module': sourceModule,
      'status': status,
      'period_start': periodStart == null ? null : _dateOnly(periodStart!),
      'period_end': periodEnd == null ? null : _dateOnly(periodEnd!),
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'title': title,
      'report_date': _dateOnly(reportDate),
      'weather': weather,
      'progress_summary': progressSummary,
      'blockers': blockers,
      'decisions': decisions,
      'next_steps': nextSteps,
      'author_id': authorId,
      'is_archived': isArchived,
      'updated_at': updatedAt.toIso8601String(),
      'report_type': reportType,
      'source_module': sourceModule,
      'status': status,
      'period_start': periodStart == null ? null : _dateOnly(periodStart!),
      'period_end': periodEnd == null ? null : _dateOnly(periodEnd!),
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  ProjectReport copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? title,
    DateTime? reportDate,
    String? weather,
    String? progressSummary,
    String? blockers,
    String? decisions,
    String? nextSteps,
    String? authorId,
    bool clearAuthorId = false,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reportType,
    String? sourceModule,
    String? status,
    DateTime? periodStart,
    bool clearPeriodStart = false,
    DateTime? periodEnd,
    bool clearPeriodEnd = false,
    DateTime? generatedAt,
    bool clearGeneratedAt = false,
  }) {
    return ProjectReport(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      reportDate: reportDate ?? this.reportDate,
      weather: weather ?? this.weather,
      progressSummary: progressSummary ?? this.progressSummary,
      blockers: blockers ?? this.blockers,
      decisions: decisions ?? this.decisions,
      nextSteps: nextSteps ?? this.nextSteps,
      authorId: clearAuthorId ? null : authorId ?? this.authorId,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reportType: reportType ?? this.reportType,
      sourceModule: sourceModule ?? this.sourceModule,
      status: status ?? this.status,
      periodStart: clearPeriodStart ? null : periodStart ?? this.periodStart,
      periodEnd: clearPeriodEnd ? null : periodEnd ?? this.periodEnd,
      generatedAt: clearGeneratedAt ? null : generatedAt ?? this.generatedAt,
    );
  }

  static String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        projectId,
        title,
        reportDate,
        weather,
        progressSummary,
        blockers,
        decisions,
        nextSteps,
        authorId,
        isArchived,
        createdAt,
        updatedAt,
        reportType,
        sourceModule,
        status,
        periodStart,
        periodEnd,
        generatedAt,
      ];
}
