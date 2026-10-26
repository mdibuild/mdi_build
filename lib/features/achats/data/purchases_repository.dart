import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/purchase_workflow.dart';

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

  /// Nom affiché de l'utilisateur connecté (pour l'historique).
  String? _actorName;

  Future<String> _currentActorName() async {
    final cached = _actorName;
    if (cached != null) {
      return cached;
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return '';
    }
    try {
      final row = await _client
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      final name = (row?['full_name'] ?? '').toString().trim();
      return _actorName = name.isNotEmpty
          ? name
          : (row?['email'] ?? user.email ?? '').toString();
    } catch (_) {
      return user.email ?? '';
    }
  }

  /// Historique d'un achat, du plus ancien au plus récent.
  Future<List<PurchaseEvent>> fetchEvents(String purchaseId) async {
    final rows = await _client
        .from('purchase_events')
        .select()
        .eq('purchase_id', purchaseId)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => PurchaseEvent.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Ajoute un évènement à l'historique. Un échec (table absente…) ne
  /// bloque jamais l'opération sur l'achat lui-même.
  Future<void> addEvent({
    required String companyId,
    required String purchaseId,
    required String kind,
    String? status,
    String comment = '',
  }) async {
    try {
      await _client.from('purchase_events').insert({
        'company_id': companyId,
        'purchase_id': purchaseId,
        'kind': kind,
        'status': status,
        'comment': comment,
        'actor_id': _client.auth.currentUser?.id,
        'actor_name': await _currentActorName(),
      });
    } catch (error) {
      debugPrint('Historique achat indisponible : $error');
    }
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

    await addEvent(
      companyId: purchase.companyId,
      purchaseId: purchaseId,
      kind: 'creation',
      status: 'brouillon',
      comment: '${purchase.title} · ${items.length} article(s)',
    );
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

    await addEvent(
      companyId: purchase.companyId,
      purchaseId: purchase.id,
      kind: 'modification',
      comment: '${items.length} article(s)',
    );
  }

  Future<void> deletePurchase(String purchaseId) async {
    await _client.from('purchases').delete().eq('id', purchaseId);
  }

  Future<void> updatePurchaseStatus({
    required String purchaseId,
    required String status,
    String? actorId,
    String comment = '',
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

    final row = await _client
        .from('purchases')
        .update(payload)
        .eq('id', purchaseId)
        .select()
        .single();
    final companyId = row['company_id'].toString();

    // N° de bon de commande attribué une seule fois, au passage en commande.
    String? orderNumber = row['order_number']?.toString();
    if (status == 'commande' && orderNumber == null) {
      try {
        final year = DateTime.now().year;
        final existing = await _client
            .from('purchases')
            .select('order_number')
            .eq('company_id', companyId)
            .like('order_number', 'BC-$year-%');
        orderNumber = nextOrderNumber(
          (existing as List<dynamic>)
              .map((r) => (r as Map)['order_number']?.toString()),
          year,
        );
        await _client
            .from('purchases')
            .update({'order_number': orderNumber}).eq('id', purchaseId);
      } catch (error) {
        orderNumber = null;
        debugPrint('Numéro de commande indisponible : $error');
      }
    }

    await addEvent(
      companyId: companyId,
      purchaseId: purchaseId,
      kind: 'statut',
      status: status,
      comment: [
        if (orderNumber != null && status == 'commande')
          'Bon de commande $orderNumber',
        if (comment.trim().isNotEmpty) comment.trim(),
      ].join(' · '),
    );
  }
}
