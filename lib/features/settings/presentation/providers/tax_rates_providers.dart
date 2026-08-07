import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/tax_rate.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/tax_rates_repository.dart';

final taxRatesRepositoryProvider = Provider<TaxRatesRepository>((ref) {
  return TaxRatesRepository();
});

final activeTaxRatesProvider = FutureProvider<List<TaxRate>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(taxRatesRepositoryProvider).fetchTaxRates(
        companyId: profile.companyId,
        archived: false,
      );
});

final archivedTaxRatesProvider = FutureProvider<List<TaxRate>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(taxRatesRepositoryProvider).fetchTaxRates(
        companyId: profile.companyId,
        archived: true,
      );
});
