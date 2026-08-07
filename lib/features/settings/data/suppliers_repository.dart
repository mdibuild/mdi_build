import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/supplier.dart';
import '../../../core/services/supabase_service.dart';

class SuppliersRepository {
  SuppliersRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Supplier>> fetchSuppliers({
    required String companyId,
    required bool archived,
  }) async {
    final rows = await _client
        .from('suppliers')
        .select()
        .eq('company_id', companyId)
        .eq('is_archived', archived)
        .order('name', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => Supplier.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier(Supplier entry) async {
    final row = await _client
        .from('suppliers')
        .insert(entry.toInsertMap())
        .select()
        .single();

    return Supplier.fromMap(row);
  }

  Future<Supplier> updateSupplier(Supplier entry) async {
    final row = await _client
        .from('suppliers')
        .update(entry.toUpdateMap())
        .eq('id', entry.id)
        .select()
        .single();

    return Supplier.fromMap(row);
  }

  Future<void> setArchived({
    required String supplierId,
    required bool archived,
  }) async {
    await _client.from('suppliers').update({
      'is_archived': archived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', supplierId);
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _client.from('suppliers').delete().eq('id', supplierId);
  }
}
