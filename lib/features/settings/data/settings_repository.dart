import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/settings_user_entry.dart';
import '../../../core/services/supabase_service.dart';

class SettingsRepository {
  SettingsRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<SettingsUserEntry>> fetchCompanyUsers(String companyId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id, company_id, full_name, email, role, created_at')
          .eq('company_id', companyId)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .map((row) => SettingsUserEntry.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final rows =
          await _client.from('profiles').select().eq('company_id', companyId);

      return (rows as List<dynamic>)
          .map((row) => SettingsUserEntry.fromMap(row as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await _client.from('profiles').update({
      'role': role,
    }).eq('id', userId);
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    await _invokeAdminUsers({
      'action': 'create',
      'username': username,
      'password': password,
      'role': role,
    });
  }

  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    await _invokeAdminUsers({
      'action': 'reset_password',
      'userId': userId,
      'newPassword': newPassword,
    });
  }

  Future<void> _invokeAdminUsers(Map<String, dynamic> body) async {
    try {
      await _client.functions.invoke('admin-users', body: body);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : error.reasonPhrase ?? 'Erreur serveur (code ${error.status}).';
      throw Exception(message);
    }
  }
}
