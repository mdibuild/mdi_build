import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_document.dart';
import '../../data/documents_repository.dart';
import '../../../projects/presentation/providers/project_scope_provider.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository();
});

final activeDocumentsProvider =
    FutureProvider<List<ProjectDocument>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(documentsRepositoryProvider).fetchDocuments(
            projectId: projectId,
            archived: false,
          ));
});

final archivedDocumentsProvider =
    FutureProvider<List<ProjectDocument>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(documentsRepositoryProvider).fetchDocuments(
            projectId: projectId,
            archived: true,
          ));
});

final taskDocumentsProvider =
    FutureProvider.family<List<ProjectDocument>, String>((ref, taskId) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) => ref.watch(documentsRepositoryProvider).fetchDocuments(
            projectId: projectId,
            archived: false,
            taskId: taskId,
          ));
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
