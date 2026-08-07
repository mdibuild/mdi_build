import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/client.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../data/clients_repository.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository();
});

final activeClientsProvider = FutureProvider<List<Client>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(clientsRepositoryProvider).fetchClients(
        companyId: profile.companyId,
        archived: false,
      );
});

final archivedClientsProvider = FutureProvider<List<Client>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return [];
  }

  return ref.watch(clientsRepositoryProvider).fetchClients(
        companyId: profile.companyId,
        archived: true,
      );
});
