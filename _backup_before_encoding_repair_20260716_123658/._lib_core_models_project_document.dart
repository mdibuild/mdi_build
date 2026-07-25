import 'package:equatable/equatable.dart';

class ProjectDocument extends Equatable {
  const ProjectDocument({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.bucketId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.title,
    required this.description,
    required this.category,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.uploadedBy,
    this.taskId,
    this.purchaseId,
    this.reportId,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String bucketId;
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String title;
  final String description;
  final String category;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? uploadedBy;
  final String? taskId;
  final String? purchaseId;
  final String? reportId;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  factory ProjectDocument.fromMap(Map<String, dynamic> map) {
    return ProjectDocument(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      bucketId: (map['bucket_id'] as String?) ?? 'project-documents',
      filePath: (map['file_path'] as String?) ?? '',
      fileName: (map['file_name'] as String?) ?? '',
      mimeType: (map['mime_type'] as String?) ?? '',
      fileSize: _toInt(map['file_size']),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'autre',
      isArchived: (map['is_archived'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      uploadedBy: map['uploaded_by'] as String?,
      taskId: map['task_id'] as String?,
      purchaseId: map['purchase_id'] as String?,
      reportId: map['report_id'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'project_id': projectId,
      'bucket_id': bucketId,
      'file_path': filePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'title': title,
      'description': description,
      'category': category,
      'is_archived': isArchived,
      'uploaded_by': uploadedBy,
      'task_id': taskId,
      'purchase_id': purchaseId,
      'report_id': reportId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'bucket_id': bucketId,
      'file_path': filePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'title': title,
      'description': description,
      'category': category,
      'is_archived': isArchived,
      'uploaded_by': uploadedBy,
      'task_id': taskId,
      'purchase_id': purchaseId,
      'report_id': reportId,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProjectDocument copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? bucketId,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? title,
    String? description,
    String? category,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? uploadedBy,
    bool clearUploadedBy = false,
    String? taskId,
    bool clearTaskId = false,
    String? purchaseId,
    bool clearPurchaseId = false,
    String? reportId,
    bool clearReportId = false,
  }) {
    return ProjectDocument(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      bucketId: bucketId ?? this.bucketId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadedBy: clearUploadedBy ? null : uploadedBy ?? this.uploadedBy,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
      purchaseId: clearPurchaseId ? null : purchaseId ?? this.purchaseId,
      reportId: clearReportId ? null : reportId ?? this.reportId,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        projectId,
        bucketId,
        filePath,
        fileName,
        mimeType,
        fileSize,
        title,
        description,
        category,
        isArchived,
        createdAt,
        updatedAt,
        uploadedBy,
        taskId,
        purchaseId,
        reportId,
      ];
}
