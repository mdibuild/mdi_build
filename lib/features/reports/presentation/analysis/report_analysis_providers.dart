import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_document.dart';
import '../../../../core/models/space_item.dart';
import '../../analysis/report_analysis_repository.dart';

final reportAnalysisRepositoryProvider =
    Provider<ReportAnalysisRepository>((ref) => ReportAnalysisRepository());

// Données chargées une fois par projet (exhaustives, toutes pages lues),
// puis filtrées localement : changer de période ou de filtre est instantané.

final reportPurchasesDataProvider =
    FutureProvider.family<PurchasesData, String>((ref, projectId) {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportAnalysisRepositoryProvider).loadPurchases(projectId);
});

final reportQuotesDataProvider =
    FutureProvider.family<QuotesData, String>((ref, projectId) {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportAnalysisRepositoryProvider).loadQuotes(projectId);
});

final reportPlanningDataProvider =
    FutureProvider.family<PlanningData, String>((ref, projectId) {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportAnalysisRepositoryProvider).loadPlanning(projectId);
});

final reportDocumentsDataProvider =
    FutureProvider.family<List<ProjectDocument>, String>((ref, projectId) {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportAnalysisRepositoryProvider).loadDocuments(projectId);
});

final reportSpacesDataProvider =
    FutureProvider.family<List<SpaceItem>, String>((ref, projectId) {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(reportAnalysisRepositoryProvider).loadSpaces(projectId);
});
