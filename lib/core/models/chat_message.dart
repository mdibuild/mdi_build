import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.senderName,
    required this.messageType,
    required this.textContent,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
    this.senderId,
    this.bucketId,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.audioDurationMs,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? senderId;
  final String senderName;
  final String messageType;
  final String textContent;
  final String? bucketId;
  final String? filePath;
  final String? fileName;
  final String? mimeType;
  final int fileSize;
  final int? audioDurationMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isFile => messageType == 'file';
  bool get isAudio => messageType == 'audio';
  bool get hasAttachment =>
      (bucketId ?? '').isNotEmpty && (filePath ?? '').isNotEmpty;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      senderId: map['sender_id']?.toString(),
      senderName: (map['sender_name'] as String?) ?? 'Utilisateur',
      messageType: (map['message_type'] as String?) ?? 'text',
      textContent: (map['text_content'] as String?) ?? '',
      bucketId: map['bucket_id']?.toString(),
      filePath: map['file_path']?.toString(),
      fileName: map['file_name']?.toString(),
      mimeType: map['mime_type']?.toString(),
      fileSize: _toInt(map['file_size']),
      audioDurationMs: map['audio_duration_ms'] == null
          ? null
          : _toInt(map['audio_duration_ms']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'project_id': projectId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message_type': messageType,
      'text_content': textContent,
      'bucket_id': bucketId,
      'file_path': filePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'audio_duration_ms': audioDurationMs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
        senderId,
        senderName,
        messageType,
        textContent,
        bucketId,
        filePath,
        fileName,
        mimeType,
        fileSize,
        audioDurationMs,
        createdAt,
        updatedAt,
      ];
}
