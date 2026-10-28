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
    this.dueAt,
    this.assignedTo,
    this.reminderMinutes = 0,
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

  /// Échéance précise (date et heure, heure locale).
  final DateTime? dueAt;

  /// Utilisateur à qui la tâche est destinée.
  final String? assignedTo;

  /// Rappel en minutes avant l'échéance (0 = à l'heure, null = aucun).
  final int? reminderMinutes;

  /// Échéance effective : l'heure si elle est connue, sinon la fin du jour.
  DateTime? get deadline {
    final at = dueAt;
    if (at != null) {
      return at;
    }
    final d = dueDate;
    return d == null ? null : DateTime(d.year, d.month, d.day, 23, 59);
  }

  /// Moment du rappel, ou null s'il n'y en a pas.
  DateTime? get reminderAt {
    final at = dueAt;
    final minutes = reminderMinutes;
    if (at == null || minutes == null || isDone) {
      return null;
    }
    return at.subtract(Duration(minutes: minutes));
  }

  bool isOverdue({DateTime? today}) {
    if (isDone) {
      return false;
    }
    final now = today ?? DateTime.now();
    final at = dueAt;
    if (at != null) {
      return now.isAfter(at);
    }
    final due = dueDate;
    return due != null && DateTime(now.year, now.month, now.day).isAfter(due);
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
      dueAt: map['due_at'] == null
          ? null
          : DateTime.tryParse(map['due_at'].toString())?.toLocal(),
      assignedTo: map['assigned_to']?.toString(),
      reminderMinutes: map.containsKey('reminder_minutes')
          ? (map['reminder_minutes'] as num?)?.toInt()
          : 0,
    );
  }

  /// Champs modifiables (colonnes v2.3 envoyées si elles servent, ou
  /// pour effacer une échéance déjà enregistrée).
  Map<String, dynamic> toUpdateMap({bool clearSchedule = false}) => {
        'title': title,
        'project_id': projectId,
        'due_date': dueDate == null
            ? null
            : '${dueDate!.year.toString().padLeft(4, '0')}-'
                '${dueDate!.month.toString().padLeft(2, '0')}-'
                '${dueDate!.day.toString().padLeft(2, '0')}',
        'client_id': clientId,
        'supplier_id': supplierId,
        if (dueAt != null || clearSchedule)
          'due_at': dueAt?.toUtc().toIso8601String(),
        if (assignedTo != null || clearSchedule) 'assigned_to': assignedTo,
        if (dueAt != null || clearSchedule) 'reminder_minutes': reminderMinutes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  ChecklistItem copyWith({
    String? title,
    DateTime? dueAt,
    bool clearDue = false,
    String? assignedTo,
    bool clearAssignee = false,
    int? reminderMinutes,
    bool clearReminder = false,
  }) {
    final due = clearDue ? null : dueAt ?? this.dueAt;
    return ChecklistItem(
      id: id,
      companyId: companyId,
      projectId: projectId,
      title: title ?? this.title,
      isDone: isDone,
      dueDate: due == null
          ? (clearDue ? null : dueDate)
          : DateTime(due.year, due.month, due.day),
      dueAt: due,
      assignedTo: clearAssignee ? null : assignedTo ?? this.assignedTo,
      reminderMinutes:
          clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
      clientId: clientId,
      supplierId: supplierId,
      sortOrder: sortOrder,
      createdBy: createdBy,
      doneAt: doneAt,
      createdAt: createdAt,
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
        // Colonnes v2.3 : envoyées seulement quand elles servent.
        if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (dueAt != null) 'reminder_minutes': reminderMinutes,
      };
}
