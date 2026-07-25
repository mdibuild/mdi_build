import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/space_item.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';
import '../../data/spaces_repository.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepository();
});

final spacesProvider = FutureProvider<List<SpaceItem>>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return [];
  }
  return ref.watch(spacesRepositoryProvider).fetchSpaces(project.id);
});
