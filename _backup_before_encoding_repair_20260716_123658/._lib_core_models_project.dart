import '../enums/record_status.dart';

class Project {
  const Project({
    required this.id,
    required this.companyId,
    required this.name,
    required this.clientName,
    required this.location,
    required this.description,
    required this.budgetInitial,
    required this.progress,
    required this.status,
  });

  final String id;
  final String companyId;
  final String name;
  final String clientName;
  final String location;
  final String description;
  final double budgetInitial;
  final double progress;
  final RecordStatus status;

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      name: map['name'] as String? ?? '',
      clientName: map['client_name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      description: map['description'] as String? ?? '',
      budgetInitial: (map['budget_initial'] as num?)?.toDouble() ?? 0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      status: RecordStatus.fromDb(map['status'] as String? ?? 'brouillon'),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'name': name,
      'client_name': clientName,
      'location': location,
      'description': description,
      'budget_initial': budgetInitial,
      'progress': progress,
      'status': status.dbValue,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'client_name': clientName,
      'location': location,
      'description': description,
      'budget_initial': budgetInitial,
      'progress': progress,
      'status': status.dbValue,
    };
  }
}
