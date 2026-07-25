class Purchase {
  const Purchase({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.title,
    required this.lot,
    required this.notes,
    required this.status,
    required this.requestedBy,
    required this.approvedBy,
    required this.orderedBy,
    required this.deliveredBy,
    required this.cancelledBy,
    required this.archivedBy,
    required this.approvedAt,
    required this.orderedAt,
    required this.deliveredAt,
    required this.cancelledAt,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String title;
  final String lot;
  final String notes;
  final String status;
  final String? requestedBy;
  final String? approvedBy;
  final String? orderedBy;
  final String? deliveredBy;
  final String? cancelledBy;
  final String? archivedBy;
  final DateTime? approvedAt;
  final DateTime? orderedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => status == 'archive';

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String? ?? '',
      lot: map['lot'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'brouillon',
      requestedBy: map['requested_by'] as String?,
      approvedBy: map['approved_by'] as String?,
      orderedBy: map['ordered_by'] as String?,
      deliveredBy: map['delivered_by'] as String?,
      cancelledBy: map['cancelled_by'] as String?,
      archivedBy: map['archived_by'] as String?,
      approvedAt: _dateTimeOrNull(map['approved_at']),
      orderedAt: _dateTimeOrNull(map['ordered_at']),
      deliveredAt: _dateTimeOrNull(map['delivered_at']),
      cancelledAt: _dateTimeOrNull(map['cancelled_at']),
      archivedAt: _dateTimeOrNull(map['archived_at']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'title': title,
      'lot': lot,
      'notes': notes,
      'status': status,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'ordered_by': orderedBy,
      'delivered_by': deliveredBy,
      'cancelled_by': cancelledBy,
      'archived_by': archivedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'ordered_at': orderedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'project_id': projectId,
      'title': title,
      'lot': lot,
      'notes': notes,
      'status': status,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'ordered_by': orderedBy,
      'delivered_by': deliveredBy,
      'cancelled_by': cancelledBy,
      'archived_by': archivedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'ordered_at': orderedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  Purchase copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? title,
    String? lot,
    String? notes,
    String? status,
    String? requestedBy,
    String? approvedBy,
    String? orderedBy,
    String? deliveredBy,
    String? cancelledBy,
    String? archivedBy,
    DateTime? approvedAt,
    DateTime? orderedAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      lot: lot ?? this.lot,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      orderedBy: orderedBy ?? this.orderedBy,
      deliveredBy: deliveredBy ?? this.deliveredBy,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      archivedBy: archivedBy ?? this.archivedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      orderedAt: orderedAt ?? this.orderedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}
