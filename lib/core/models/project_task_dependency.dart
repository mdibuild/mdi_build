class ProjectTaskDependency {
  const ProjectTaskDependency({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.predecessorTaskId,
    required this.successorTaskId,
    required this.dependencyType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String predecessorTaskId;
  final String successorTaskId;
  final String dependencyType;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFinishToStart => dependencyType == 'finish_to_start';
  bool get isStartToFinish => dependencyType == 'start_to_finish';
  bool get isStartToStart => dependencyType == 'start_to_start';
  bool get isFinishToFinish => dependencyType == 'finish_to_finish';

  factory ProjectTaskDependency.fromMap(Map<String, dynamic> map) {
    return ProjectTaskDependency(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      predecessorTaskId: map['predecessor_task_id'] as String,
      successorTaskId: map['successor_task_id'] as String,
      dependencyType: map['dependency_type'] as String? ?? 'finish_to_start',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'predecessor_task_id': predecessorTaskId,
      'successor_task_id': successorTaskId,
      'dependency_type': dependencyType,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'predecessor_task_id': predecessorTaskId,
      'successor_task_id': successorTaskId,
      'dependency_type': dependencyType,
    };
  }

  ProjectTaskDependency copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? predecessorTaskId,
    String? successorTaskId,
    String? dependencyType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectTaskDependency(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      predecessorTaskId: predecessorTaskId ?? this.predecessorTaskId,
      successorTaskId: successorTaskId ?? this.successorTaskId,
      dependencyType: dependencyType ?? this.dependencyType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
