import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/company.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/company_repository.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository();
});

final currentCompanyProvider = FutureProvider<Company?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return null;
  }

  return ref.watch(companyRepositoryProvider).fetchCompany(profile.companyId);
});
