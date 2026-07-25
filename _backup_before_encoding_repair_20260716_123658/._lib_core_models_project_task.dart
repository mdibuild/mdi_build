class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.parentTaskId,
    required this.taskType,
    required this.title,
    required this.description,
    required this.lot,
    required this.assignedTo,
    required this.createdBy,
    required this.status,
    required this.priority,
    required this.progress,
    required this.plannedStartDate,
    required this.plannedEndDate,
    required this.plannedDurationDays,
    required this.actualStartDate,
    required this.actualEndDate,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? parentTaskId;
  final String taskType;
  final String title;
  final String description;
  final String lot;
  final String? assignedTo;
  final String? createdBy;
  final String status;
  final String priority;
  final double progress;
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final int plannedDurationDays;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMilestone => taskType == 'milestone';

  factory ProjectTask.fromMap(Map<String, dynamic> map) {
    return ProjectTask(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      parentTaskId: map['parent_task_id'] as String?,
      taskType: map['task_type'] as String? ?? 'task',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      lot: map['lot'] as String? ?? 'general',
      assignedTo: map['assigned_to'] as String?,
      createdBy: map['created_by'] as String?,
      status: map['status'] as String? ?? 'brouillon',
      priority: map['priority'] as String? ?? 'normale',
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      plannedStartDate: _dateOrNull(map['planned_start_date']),
      plannedEndDate: _dateOrNull(map['planned_end_date']),
      plannedDurationDays: (map['planned_duration_days'] as num?)?.toInt() ?? 0,
      actualStartDate: _dateOrNull(map['actual_start_date']),
      actualEndDate: _dateOrNull(map['actual_end_date']),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'parent_task_id': parentTaskId,
      'task_type': taskType,
      'title': title,
      'description': description,
      'lot': lot,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'status': status,
      'priority': priority,
      'progress': progress,
      'planned_start_date': _dateToString(plannedStartDate),
      'planned_end_date': _dateToString(plannedEndDate),
      'planned_duration_days': plannedDurationDays,
      'actual_start_date': _dateToString(actualStartDate),
      'actual_end_date': _dateToString(actualEndDate),
      'sort_order': sortOrder,
      'is_archived': isArchived,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'parent_task_id': parentTaskId,
      'task_type': taskType,
      'title': title,
      'description': description,
      'lot': lot,
      'assigned_to': assignedTo,
      'status': status,
      'priority': priority,
      'progress': progress,
      'planned_start_date': _dateToString(plannedStartDate),
      'planned_end_date': _dateToString(plannedEndDate),
      'planned_duration_days': plannedDurationDays,
      'actual_start_date': _dateToString(actualStartDate),
      'actual_end_date': _dateToString(actualEndDate),
      'sort_order': sortOrder,
      'is_archived': isArchived,
    };
  }

  ProjectTask copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? parentTaskId,
    String? taskType,
    String? title,
    String? description,
    String? lot,
    String? assignedTo,
    String? createdBy,
    String? status,
    String? priority,
    double? progress,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    int? plannedDurationDays,
    DateTime? actualStartDate,
    DateTime? actualEndDate,
    int? sortOrder,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectTask(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      taskType: taskType ?? this.taskType,
      title: title ?? this.title,
      description: description ?? this.description,
      lot: lot ?? this.lot,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      plannedStartDate: plannedStartDate ?? this.plannedStartDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      plannedDurationDays: plannedDurationDays ?? this.plannedDurationDays,
      actualStartDate: actualStartDate ?? this.actualStartDate,
      actualEndDate: actualEndDate ?? this.actualEndDate,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }

  static String? _dateToString(DateTime? value) {
    if (value == null) {
      return null;
    }
    return value.toIso8601String().split('T').first;
  }
}
