import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/supplier.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/suppliers_repository.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository();
});

final activeSuppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(suppliersRepositoryProvider).fetchSuppliers(
        companyId: profile.companyId,
        archived: false,
      );
});

final archivedSuppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(suppliersRepositoryProvider).fetchSuppliers(
        companyId: profile.companyId,
        archived: true,
      );
});
