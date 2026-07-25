import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/opening_item.dart';
import '../../../core/models/space_item.dart';
import '../../../core/services/supabase_service.dart';

class SpacesRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<SpaceItem>> fetchSpaces(String projectId) async {
    final spacesRows = await _client
        .from('spaces')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    final openingsRows = await _client
        .from('space_openings')
        .select()
        .eq('project_id', projectId);

    final openings = (openingsRows as List<dynamic>)
        .map((row) => OpeningItem.fromMap(row as Map<String, dynamic>))
        .toList();

    return (spacesRows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final spaceId = map['id'] as String;
      final scopedOpenings =
          openings.where((item) => item.spaceId == spaceId).toList();
      return SpaceItem.fromMap(map, openings: scopedOpenings);
    }).toList();
  }

  Future<void> createSpace(SpaceItem space) async {
    await _client.from('spaces').insert(space.toInsertMap());
  }

  Future<void> updateSpace(SpaceItem space) async {
    await _client.from('spaces').update(space.toUpdateMap()).eq('id', space.id);
  }

  Future<void> deleteSpace(String spaceId) async {
    await _client.from('spaces').delete().eq('id', spaceId);
  }

  Future<void> createOpening(OpeningItem opening) async {
    await _client.from('space_openings').insert(opening.toInsertMap());
  }

  Future<void> updateOpening(OpeningItem opening) async {
    await _client
        .from('space_openings')
        .update(opening.toUpdateMap())
        .eq('id', opening.id);
  }

  Future<void> deleteOpening(String openingId) async {
    await _client.from('space_openings').delete().eq('id', openingId);
  }
}
