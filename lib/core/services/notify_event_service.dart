import 'supabase_service.dart';

/// Déclenche une notification push server-side pour un événement (nouveau
/// message chat, changement de statut achat...). Le serveur vérifie qui
/// appelle, calcule les destinataires et respecte les préférences par module
/// de chacun — jamais bloquant pour l'action réelle en cas d'échec.
class NotifyEventService {
  NotifyEventService._();

  static Future<void> send({
    required String companyId,
    String? projectId,
    required String module,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? recipientProfileId,
  }) async {
    try {
      await SupabaseService.client.functions.invoke(
        'notify-event',
        body: {
          'companyId': companyId,
          if (projectId != null) 'projectId': projectId,
          'module': module,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
          if (recipientProfileId != null)
            'recipientProfileId': recipientProfileId,
        },
      );
    } catch (_) {
      // Les notifications ne doivent jamais bloquer une action réelle.
    }
  }
}
