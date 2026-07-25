import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_document.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../data/documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

final activeDocumentsProvider =
    FutureProvider<List<ProjectDocument>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(documentsRepositoryProvider).fetchDocuments(
        projectId: project.id,
        archived: false,
      );
});

final archivedDocumentsProvider =
    FutureProvider<List<ProjectDocument>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(documentsRepositoryProvider).fetchDocuments(
        projectId: project.id,
        archived: true,
      );
});

final taskDocumentsProvider =
    FutureProvider.family<List<ProjectDocument>, String>((ref, taskId) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(documentsRepositoryProvider).fetchDocuments(
        projectId: project.id,
        archived: false,
        taskId: taskId,
      );
});

final purchaseDocumentsProvider =
    FutureProvider.family<List<ProjectDocument>, String>(
        (ref, purchaseId) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }

  return ref.watch(documentsRepositoryProvider).fetchDocuments(
        projectId: project.id,
        archived: false,
        purchaseId: purchaseId,
      );
});
