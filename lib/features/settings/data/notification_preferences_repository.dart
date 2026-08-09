import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class NotificationPreferencesRepository {
  NotificationPreferencesRepository({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Absence de ligne = notification activée (comportement par défaut).
  Future<Map<String, bool>> fetchPreferences(String profileId) async {
    final rows = await _client
        .from('notification_preferences')
        .select('module, enabled')
        .eq('profile_id', profileId);

    return {
      for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>())
        row['module'] as String: row['enabled'] as bool,
    };
  }

  Future<void> setPreference({
    required String profileId,
    required String module,
    required bool enabled,
  }) async {
    await _client.from('notification_preferences').upsert(
      {
        'profile_id': profileId,
        'module': module,
        'enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'profile_id,module',
    );
  }
}
