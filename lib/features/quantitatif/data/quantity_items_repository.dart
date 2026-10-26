import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/quantity_item.dart';
import '../../../core/services/supabase_service.dart';

class QuantityItemsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<QuantityItem>> fetchItems(String projectId) async {
    final rows = await _client
        .from('project_quantity_items')
        .select()
        .eq('project_id', projectId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => QuantityItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> addItems(List<QuantityItem> items) async {
    if (items.isEmpty) {
      return;
    }
    await _client
        .from('project_quantity_items')
        .insert([for (final i in items) i.toInsertMap()]);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('project_quantity_items').delete().eq('id', id);
  }

  Future<void> deleteAll(String projectId) async {
    await _client
        .from('project_quantity_items')
        .delete()
        .eq('project_id', projectId);
  }
}
