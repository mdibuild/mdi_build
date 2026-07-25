import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/settings_user_entry.dart';
import '../../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final companyUsersProvider =
    FutureProvider.family<List<SettingsUserEntry>, String>(
        (ref, companyId) async {
  return ref.read(settingsRepositoryProvider).fetchCompanyUsers(companyId);
});
