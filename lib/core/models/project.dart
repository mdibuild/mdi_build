import '../enums/record_status.dart';

/// Valeur « inchangé » de copyWith pour les liens client/fournisseur
/// (permet aussi de les vider en passant null).
const Object _keepLink = Object();

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
    this.clientId,
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

  /// Client du projet (fiche client).
  final String? clientId;

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
      clientId: map['client_id']?.toString(),
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
      'client_id': clientId,
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
      'client_id': clientId,
    };
  }

  Project copyWith({
    Object? clientId = _keepLink,
    String? id,
    String? companyId,
    String? name,
    String? clientName,
    String? location,
    String? description,
    double? budgetInitial,
    double? progress,
    RecordStatus? status,
  }) {
    return Project(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      location: location ?? this.location,
      description: description ?? this.description,
      budgetInitial: budgetInitial ?? this.budgetInitial,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      clientId:
          identical(clientId, _keepLink) ? this.clientId : clientId as String?,
    );
  }
}
