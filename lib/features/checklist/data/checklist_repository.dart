import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/checklist_item.dart';
import '../../../core/services/supabase_service.dart';

class ChecklistRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Éléments de l'entreprise : ceux du chantier [projectId] et les
  /// éléments généraux (sans chantier). Sans [projectId] : tout.
  Future<List<ChecklistItem>> fetchItems({
    required String companyId,
    String? projectId,
  }) async {
    var query =
        _client.from('checklist_items').select().eq('company_id', companyId);
    if (projectId != null) {
      query = query.or('project_id.eq.$projectId,project_id.is.null');
    }
    final rows = await query
        .order('is_done', ascending: true)
        .order('due_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => ChecklistItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> addItem(ChecklistItem item) async {
    await _client.from('checklist_items').insert(item.toInsertMap());
  }

  Future<void> setDone(String id, bool done) async {
    await _client.from('checklist_items').update({
      'is_done': done,
      'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('checklist_items').delete().eq('id', id);
  }

  Future<void> deleteDone(
      {required String companyId, String? projectId}) async {
    var query = _client
        .from('checklist_items')
        .delete()
        .eq('company_id', companyId)
        .eq('is_done', true);
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    await query;
  }
}
