import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/client.dart';
import '../../../core/services/supabase_service.dart';

class ClientsRepository {
  ClientsRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Client>> fetchClients({
    required String companyId,
    required bool archived,
  }) async {
    final rows = await _client
        .from('clients')
        .select()
        .eq('company_id', companyId)
        .eq('is_archived', archived)
        .order('name', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => Client.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Client> createClient(Client entry) async {
    final row = await _client
        .from('clients')
        .insert(entry.toInsertMap())
        .select()
        .single();

    return Client.fromMap(row);
  }

  Future<Client> updateClient(Client entry) async {
    final row = await _client
        .from('clients')
        .update(entry.toUpdateMap())
        .eq('id', entry.id)
        .select()
        .single();

    return Client.fromMap(row);
  }

  Future<void> setArchived({
    required String clientId,
    required bool archived,
  }) async {
    await _client.from('clients').update({
      'is_archived': archived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clientId);
  }

  Future<void> deleteClient(String clientId) async {
    await _client.from('clients').delete().eq('id', clientId);
  }
}
