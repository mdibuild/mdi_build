import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/quantity_item.dart';
import '../../../../core/models/space_item.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../../quantitatif/data/quantity_items_repository.dart';
import '../../data/spaces_repository.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepository();
});

final spacesProvider = FutureProvider<List<SpaceItem>>((ref) async {
  ref.watch(moduleRefreshRevisionProvider);
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }
  return ref.watch(spacesRepositoryProvider).fetchSpaces(project.id);
});

final quantityItemsRepositoryProvider =
    Provider<QuantityItemsRepository>((ref) => QuantityItemsRepository());

/// Quantités importées (Excel) du chantier.
final quantityItemsProvider =
    FutureProvider.family<List<QuantityItem>, String>((ref, projectId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(quantityItemsRepositoryProvider).fetchItems(projectId);
});
