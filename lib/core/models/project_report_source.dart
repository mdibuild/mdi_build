import 'package:equatable/equatable.dart';

class ProjectReportSource extends Equatable {
  const ProjectReportSource({
    required this.id,
    required this.companyId,
    required this.reportId,
    required this.moduleName,
    required this.sourceEntityType,
    required this.snapshotJson,
    required this.createdAt,
    required this.updatedAt,
    this.sourceEntityId,
  });

  final String id;
  final String companyId;
  final String reportId;
  final String moduleName;
  final String sourceEntityType;
  final String? sourceEntityId;
  final Map<String, dynamic> snapshotJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectReportSource.fromMap(Map<String, dynamic> map) {
    return ProjectReportSource(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      reportId: map['report_id'] as String,
      moduleName: (map['module_name'] as String?) ?? '',
      sourceEntityType: (map['source_entity_type'] as String?) ?? '',
      sourceEntityId: map['source_entity_id']?.toString(),
      snapshotJson: _toMap(map['snapshot_json']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'report_id': reportId,
      'module_name': moduleName,
      'source_entity_type': sourceEntityType,
      'source_entity_id': sourceEntityId,
      'snapshot_json': snapshotJson,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        reportId,
        moduleName,
        sourceEntityType,
        sourceEntityId,
        snapshotJson,
        createdAt,
        updatedAt,
      ];
}
