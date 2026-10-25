/// Élément de check-list : une chose à faire, cochée une fois faite.
/// Rattaché à un chantier, ou général (sans chantier).
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.companyId,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.projectId,
    this.dueDate,
    this.clientId,
    this.supplierId,
    this.sortOrder = 0,
    this.createdBy,
    this.doneAt,
  });

  final String id;
  final String companyId;
  final String? projectId;
  final String title;
  final bool isDone;
  final DateTime? dueDate;
  final String? clientId;
  final String? supplierId;
  final int sortOrder;
  final String? createdBy;
  final DateTime? doneAt;
  final DateTime createdAt;

  bool isOverdue({DateTime? today}) {
    final due = dueDate;
    if (isDone || due == null) {
      return false;
    }
    final now = today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day).isAfter(due);
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    DateTime? date(dynamic v) {
      final d = v == null ? null : DateTime.tryParse(v.toString());
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    return ChecklistItem(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id']?.toString(),
      title: map['title'] as String? ?? '',
      isDone: map['is_done'] as bool? ?? false,
      dueDate: date(map['due_date']),
      clientId: map['client_id']?.toString(),
      supplierId: map['supplier_id']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdBy: map['created_by']?.toString(),
      doneAt: map['done_at'] == null
          ? null
          : DateTime.tryParse(map['done_at'].toString()),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'company_id': companyId,
        'project_id': projectId,
        'title': title,
        'is_done': isDone,
        'due_date': dueDate == null
            ? null
            : '${dueDate!.year.toString().padLeft(4, '0')}-'
                '${dueDate!.month.toString().padLeft(2, '0')}-'
                '${dueDate!.day.toString().padLeft(2, '0')}',
        'client_id': clientId,
        'supplier_id': supplierId,
        'sort_order': sortOrder,
        'created_by': createdBy,
      };
}
