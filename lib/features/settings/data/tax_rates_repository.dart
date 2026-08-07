import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/tax_rate.dart';
import '../../../core/services/supabase_service.dart';

class TaxRatesRepository {
  TaxRatesRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<TaxRate>> fetchTaxRates({
    required String companyId,
    required bool archived,
  }) async {
    final rows = await _client
        .from('tax_rates')
        .select()
        .eq('company_id', companyId)
        .eq('is_archived', archived)
        .order('label', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => TaxRate.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<TaxRate> createTaxRate(TaxRate entry) async {
    if (entry.isDefault) {
      await _clearOtherDefaults(companyId: entry.companyId, exceptId: null);
    }

    final row = await _client
        .from('tax_rates')
        .insert(entry.toInsertMap())
        .select()
        .single();

    return TaxRate.fromMap(row);
  }

  Future<TaxRate> updateTaxRate(TaxRate entry) async {
    if (entry.isDefault) {
      await _clearOtherDefaults(companyId: entry.companyId, exceptId: entry.id);
    }

    final row = await _client
        .from('tax_rates')
        .update(entry.toUpdateMap())
        .eq('id', entry.id)
        .select()
        .single();

    return TaxRate.fromMap(row);
  }

  Future<void> setArchived({
    required String taxRateId,
    required bool archived,
  }) async {
    await _client.from('tax_rates').update({
      'is_archived': archived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taxRateId);
  }

  Future<void> deleteTaxRate(String taxRateId) async {
    await _client.from('tax_rates').delete().eq('id', taxRateId);
  }

  Future<void> _clearOtherDefaults({
    required String companyId,
    required String? exceptId,
  }) async {
    dynamic query = _client
        .from('tax_rates')
        .update({'is_default': false}).eq('company_id', companyId);

    if (exceptId != null) {
      query = query.neq('id', exceptId);
    }

    await query;
  }
}
