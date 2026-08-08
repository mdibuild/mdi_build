import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

/// Enregistre le token FCM de l'appareil courant pour l'utilisateur connecté,
/// pour que les notifications serveur (achats, messagerie, tâches) puissent
/// l'atteindre. Ne bloque jamais le reste de l'app en cas d'échec (refus de
/// permission navigateur, absence de clé VAPID en dev, etc.).
class DeviceTokenService {
  DeviceTokenService._();

  static Future<void> registerCurrentToken() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _vapidKey.isEmpty ? null : _vapidKey,
        serviceWorkerScriptPath:
            kIsWeb ? '/mdi_build/firebase-messaging-sw.js' : null,
      );
      if (token == null) {
        return;
      }

      final profileRow = await SupabaseService.client
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();
      final companyId = profileRow?['company_id'] as String?;
      if (companyId == null) {
        return;
      }

      await SupabaseService.client.from('device_tokens').upsert(
        {
          'company_id': companyId,
          'profile_id': user.id,
          'fcm_token': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
        onConflict: 'fcm_token',
      );
    } catch (_) {
      // Les notifications ne sont jamais critiques au fonctionnement de l'app.
    }
  }
}
