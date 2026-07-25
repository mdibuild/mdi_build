import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/supabase_service.dart';

class PurchasesRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Purchase>> fetchPurchases({
    required String companyId,
    bool archived = false,
  }) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
        _client.from('purchases').select().eq('company_id', companyId);

    if (archived) {
      query = query.eq('status', 'archive');
    } else {
      query = query.neq('status', 'archive');
    }

    final rows = await query.order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Purchase.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<PurchaseItem>> fetchPurchaseItems(String purchaseId) async {
    final rows = await _client
        .from('purchase_items')
        .select()
        .eq('purchase_id', purchaseId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => PurchaseItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPurchase(
      Purchase purchase, List<PurchaseItem> items) async {
    final inserted = await _client
        .from('purchases')
        .insert(purchase.toInsertMap())
        .select()
        .single();

    final purchaseId = inserted['id'] as String;

    if (items.isNotEmpty) {
      final payload = items
          .asMap()
          .entries
          .map(
            (entry) => entry.value
                .copyWith(
                  purchaseId: purchaseId,
                  sortOrder: entry.key,
                )
                .toInsertMap(),
          )
          .toList();

      await _client.from('purchase_items').insert(payload);
    }
  }

  Future<void> updatePurchase(
      Purchase purchase, List<PurchaseItem> items) async {
    await _client
        .from('purchases')
        .update(purchase.toUpdateMap())
        .eq('id', purchase.id);

    await _client
        .from('purchase_items')
        .delete()
        .eq('purchase_id', purchase.id);

    if (items.isNotEmpty) {
      final payload = items
          .asMap()
          .entries
          .map(
            (entry) => entry.value
                .copyWith(
                  purchaseId: purchase.id,
                  sortOrder: entry.key,
                )
                .toInsertMap(),
          )
          .toList();

      await _client.from('purchase_items').insert(payload);
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    await _client.from('purchases').delete().eq('id', purchaseId);
  }

  Future<void> updatePurchaseStatus({
    required String purchaseId,
    required String status,
    String? actorId,
  }) async {
    final now = DateTime.now().toIso8601String();

    final payload = <String, dynamic>{
      'status': status,
    };

    if (status == 'dg_valide') {
      payload['approved_by'] = actorId;
      payload['approved_at'] = now;
    } else if (status == 'commande') {
      payload['ordered_by'] = actorId;
      payload['ordered_at'] = now;
    } else if (status == 'livre') {
      payload['delivered_by'] = actorId;
      payload['delivered_at'] = now;
    } else if (status == 'annule') {
      payload['cancelled_by'] = actorId;
      payload['cancelled_at'] = now;
    } else if (status == 'archive') {
      payload['archived_by'] = actorId;
      payload['archived_at'] = now;
    }

    await _client.from('purchases').update(payload).eq('id', purchaseId);
  }
}
