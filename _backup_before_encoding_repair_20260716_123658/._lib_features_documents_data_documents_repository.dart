import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_document.dart';
import '../../../core/services/supabase_service.dart';

class DocumentsRepository {
  DocumentsRepository({
    SupabaseClient? client,
    String storageBucket = 'project-documents',
  })  : _client = client ?? SupabaseService.client,
        _storageBucket = storageBucket;

  final SupabaseClient _client;
  final String _storageBucket;

  Future<List<ProjectDocument>> fetchDocuments({
    String? projectId,
    String? taskId,
    String? purchaseId,
    String? reportId,
    required bool archived,
  }) async {
    dynamic query = _client.from('project_documents').select();

    query = query.eq('is_archived', archived);

    if (projectId != null && projectId.trim().isNotEmpty) {
      query = query.eq('project_id', projectId);
    }
    if (taskId != null && taskId.trim().isNotEmpty) {
      query = query.eq('task_id', taskId);
    }
    if (purchaseId != null && purchaseId.trim().isNotEmpty) {
      query = query.eq('purchase_id', purchaseId);
    }
    if (reportId != null && reportId.trim().isNotEmpty) {
      query = query.eq('report_id', reportId);
    }

    final rows = await query.order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => ProjectDocument.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProjectDocument>> fetchProjectDocuments({
    required String projectId,
    required bool archived,
  }) {
    return fetchDocuments(
      projectId: projectId,
      archived: archived,
    );
  }

  Future<List<ProjectDocument>> fetchTaskDocuments(
    String taskId, {
    bool archived = false,
  }) {
    return fetchDocuments(
      taskId: taskId,
      archived: archived,
    );
  }

  Future<List<ProjectDocument>> fetchPurchaseDocuments(
    String purchaseId, {
    bool archived = false,
  }) {
    return fetchDocuments(
      purchaseId: purchaseId,
      archived: archived,
    );
  }

  Future<List<ProjectDocument>> fetchReportDocuments(
    String reportId, {
    bool archived = false,
  }) {
    return fetchDocuments(
      reportId: reportId,
      archived: archived,
    );
  }

  String buildStoragePath({
    required String projectId,
    String? fileName,
    String? originalFileName,
    String? taskId,
    String? purchaseId,
    String? reportId,
  }) {
    final rawName = (fileName ?? originalFileName ?? 'document.bin').trim();
    final safeName = _sanitizeFileName(rawName);
    final stamp = DateTime.now().microsecondsSinceEpoch;

    String folder = 'general';
    if (taskId != null && taskId.trim().isNotEmpty) {
      folder = 'tasks/$taskId';
    } else if (purchaseId != null && purchaseId.trim().isNotEmpty) {
      folder = 'purchases/$purchaseId';
    } else if (reportId != null && reportId.trim().isNotEmpty) {
      folder = 'reports/$reportId';
    }

    return 'projects/$projectId/$folder/${stamp}_$safeName';
  }

  Future<void> uploadFileBytes({
    String? storagePath,
    String? filePath,
    String? path,
    required Uint8List bytes,
    String? contentType,
    String? mimeType,
    String? bucketId,
  }) async {
    final targetPath = (storagePath ?? filePath ?? path ?? '').trim();

    if (targetPath.isEmpty) {
      throw ArgumentError('storagePath/filePath/path manquant');
    }

    final resolvedContentType =
        (mimeType ?? contentType ?? 'application/octet-stream').trim();

    await _client.storage.from(bucketId ?? _storageBucket).uploadBinary(
          targetPath,
          bytes,
          fileOptions: FileOptions(
            contentType: resolvedContentType,
            upsert: false,
          ),
        );
  }

  Future<String> uploadBytes({
    required String filePath,
    required Uint8List bytes,
    required String contentType,
    String? bucketId,
    FileOptions? options,
  }) async {
    await _client.storage.from(bucketId ?? _storageBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: options ??
              FileOptions(
                contentType: contentType,
                upsert: false,
              ),
        );

    return filePath;
  }

  Future<void> deleteFile({
    required String bucketId,
    String? path,
    String? filePath,
  }) async {
    final targetPath = (filePath ?? path ?? '').trim();
    if (targetPath.isEmpty) {
      return;
    }

    await _client.storage.from(bucketId).remove([targetPath]);
  }

  Future<ProjectDocument> createDocument(ProjectDocument document) async {
    final row = await _client
        .from('project_documents')
        .insert(document.toInsertMap())
        .select()
        .single();

    return ProjectDocument.fromMap(row);
  }

  Future<ProjectDocument> updateDocument(ProjectDocument document) async {
    final row = await _client
        .from('project_documents')
        .update(document.toUpdateMap())
        .eq('id', document.id)
        .select()
        .single();

    return ProjectDocument.fromMap(row);
  }

  Future<void> setArchived({
    required String documentId,
    required bool archived,
  }) async {
    await _client.from('project_documents').update({
      'is_archived': archived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', documentId);
  }

  Future<void> deleteDocument(ProjectDocument document) async {
    try {
      await deleteFile(
        bucketId: document.bucketId,
        filePath: document.filePath,
      );
    } catch (_) {}

    await _client.from('project_documents').delete().eq('id', document.id);
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
