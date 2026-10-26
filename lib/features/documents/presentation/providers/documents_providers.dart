import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_document.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../data/documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

final activeDocumentsProvider =
    FutureProvider<List<ProjectDocument>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
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
  ref.watch(moduleRefreshRevisionProvider);
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
  ref.watch(moduleRefreshRevisionProvider);
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
  ref.watch(moduleRefreshRevisionProvider);
  // Tous les documents de l'achat, même si son chantier n'est pas le
  // chantier sélectionné.
  return ref
      .watch(documentsRepositoryProvider)
      .fetchPurchaseDocuments(purchaseId);
});
