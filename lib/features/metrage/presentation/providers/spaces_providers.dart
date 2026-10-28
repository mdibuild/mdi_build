import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/quantity_item.dart';
import '../../../../core/models/space_item.dart';
import '../../../quantitatif/data/quantity_items_repository.dart';
import '../../data/spaces_repository.dart';
import '../../../projects/presentation/providers/project_scope_provider.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepository();
});

final spacesProvider = FutureProvider<List<SpaceItem>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  // Chantier sélectionné, ou tous les projets.
  return forScopedProjects(
      ref,
      (projectId) =>
          ref.watch(spacesRepositoryProvider).fetchSpaces(projectId));
});

final quantityItemsRepositoryProvider =
    Provider<QuantityItemsRepository>((ref) => QuantityItemsRepository());

/// Quantités importées (Excel) du chantier.
final quantityItemsProvider =
    FutureProvider.family<List<QuantityItem>, String>((ref, projectId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(quantityItemsRepositoryProvider).fetchItems(projectId);
});
