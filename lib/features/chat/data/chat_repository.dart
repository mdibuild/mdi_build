import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/services/notify_event_service.dart';
import '../../../core/services/supabase_service.dart';

class ChatRepository {
  ChatRepository({
    SupabaseClient? client,
    String storageBucket = 'project-documents',
  })  : _client = client ?? SupabaseService.client,
        _storageBucket = storageBucket;

  final SupabaseClient _client;
  final String _storageBucket;

  Stream<List<ChatMessage>> streamProjectMessages(String projectId) {
    return _client
        .from('project_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .map(
          (rows) => rows.map((row) => ChatMessage.fromMap(row)).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  Future<void> sendText({
    required String companyId,
    required String projectId,
    required String senderId,
    required String senderName,
    required String text,
    String? recipientId,
    String? recipientName,
  }) async {
    final now = DateTime.now();

    final message = ChatMessage(
      id: '',
      companyId: companyId,
      projectId: projectId,
      senderId: senderId,
      senderName: senderName,
      messageType: 'text',
      textContent: text.trim(),
      fileSize: 0,
      recipientId: recipientId,
      recipientName: recipientName,
      createdAt: now,
      updatedAt: now,
    );

    await _client.from('project_chat_messages').insert(message.toInsertMap());

    await NotifyEventService.send(
      companyId: companyId,
      projectId: projectId,
      module: 'chat',
      title: senderName,
      body: message.textContent,
      recipientProfileId: recipientId,
    );
  }

  Future<void> sendBinaryMessage({
    required String companyId,
    required String projectId,
    required String senderId,
    required String senderName,
    required String messageType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    int? audioDurationMs,
    String? recipientId,
    String? recipientName,
  }) async {
    final now = DateTime.now();
    final safeFileName = _sanitizeFileName(fileName);
    final filePath =
        'chat/$projectId/${now.microsecondsSinceEpoch}_$safeFileName';

    await _client.storage.from(_storageBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    final message = ChatMessage(
      id: '',
      companyId: companyId,
      projectId: projectId,
      senderId: senderId,
      senderName: senderName,
      messageType: messageType,
      textContent: '',
      bucketId: _storageBucket,
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: bytes.length,
      audioDurationMs: audioDurationMs,
      recipientId: recipientId,
      recipientName: recipientName,
      createdAt: now,
      updatedAt: now,
    );

    await _client.from('project_chat_messages').insert(message.toInsertMap());

    await NotifyEventService.send(
      companyId: companyId,
      projectId: projectId,
      module: 'chat',
      title: senderName,
      body: _attachmentNotificationBody(messageType),
      recipientProfileId: recipientId,
    );
  }

  String _attachmentNotificationBody(String messageType) {
    switch (messageType) {
      case 'image':
        return 'Photo envoyée';
      case 'audio':
        return 'Message audio envoyé';
      default:
        return 'Fichier envoyé';
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    await _client.from('project_chat_messages').delete().eq('id', message.id);

    if (message.hasAttachment) {
      try {
        await _client.storage
            .from(message.bucketId!)
            .remove([message.filePath!]);
      } catch (_) {
        // Le message est supprimé ; la pièce jointe orpheline n'est pas bloquante.
      }
    }
  }

  Future<String> createSignedUrl({
    required String bucketId,
    required String filePath,
    int expiresInSeconds = 3600,
  }) {
    return _client.storage
        .from(bucketId)
        .createSignedUrl(filePath, expiresInSeconds);
  }

  String _sanitizeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
