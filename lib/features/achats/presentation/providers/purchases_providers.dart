import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/models/purchase_item.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/purchases_repository.dart';
import '../../../../core/models/purchase_workflow.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository();
});

final activePurchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(purchasesRepositoryProvider).fetchPurchases(
        companyId: profile.companyId,
        archived: false,
      );
});

final archivedPurchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(purchasesRepositoryProvider).fetchPurchases(
        companyId: profile.companyId,
        archived: true,
      );
});

final purchaseItemsProvider =
    FutureProvider.family<List<PurchaseItem>, String>((ref, purchaseId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.watch(purchasesRepositoryProvider).fetchPurchaseItems(purchaseId);
});

/// Historique (suivi) d'un achat.
final purchaseEventsProvider =
    FutureProvider.family<List<PurchaseEvent>, String>((ref, purchaseId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(purchasesRepositoryProvider).fetchEvents(purchaseId);
});
