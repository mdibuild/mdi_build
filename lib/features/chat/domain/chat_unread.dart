import '../../../core/models/chat_message.dart';

/// Clé de conversation d'un message : `general` ou l'identifiant du projet.
String chatConversationKey(String? projectId) => projectId ?? 'general';

/// Nombre de messages non lus par conversation.
///
/// Un message est non lu s'il est :
/// - envoyé par quelqu'un d'autre ;
/// - destiné à tout le monde, ou à moi en privé (un message privé adressé à
///   une autre personne ne me concerne pas) ;
/// - plus récent que mon dernier passage dans sa conversation, ou à défaut
///   que la date de référence [baseline] (première utilisation : on ne
///   compte pas tout l'historique comme non lu).
Map<String, int> unreadByConversation({
  required List<ChatMessage> messages,
  required String myId,
  required Map<String, DateTime> lastSeen,
  required DateTime? baseline,
}) {
  final counts = <String, int>{};
  for (final m in messages) {
    if (m.senderId == myId) {
      continue;
    }
    if (m.recipientId != null && m.recipientId != myId) {
      continue;
    }
    final key = chatConversationKey(m.projectId);
    final since = lastSeen[key] ?? baseline;
    if (since == null || !m.createdAt.isAfter(since)) {
      continue;
    }
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
