import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/models/purchase_item.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/purchases_repository.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository();
});

final activePurchasesProvider = FutureProvider<List<Purchase>>((ref) async {
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
  return ref.watch(purchasesRepositoryProvider).fetchPurchaseItems(purchaseId);
});
