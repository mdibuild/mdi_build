import '../../../core/models/chat_message.dart';

/// État d'un message que j'ai envoyé.
enum ReceiptState {
  /// ✓ enregistré sur le serveur.
  sent,

  /// ✓✓ gris : arrivé chez le destinataire (privé) ou chez tous les
  /// membres (groupe).
  delivered,

  /// ✓✓ bleu : lu par le destinataire (privé) ou par tous (groupe).
  read,
}

/// Accusé d'un message, quel que soit son type (texte, photo, audio,
/// fichier). [otherMembers] : nombre de personnes de l'entreprise autres que
/// l'expéditeur (destinataires d'un message de groupe).
ReceiptState receiptFor(ChatMessage message, {required int otherMembers}) {
  if (message.recipientId != null) {
    if (message.readAt != null) {
      return ReceiptState.read;
    }
    if (message.deliveredAt != null) {
      return ReceiptState.delivered;
    }
    return ReceiptState.sent;
  }
  if (otherMembers <= 0) {
    return ReceiptState.sent;
  }
  final readers = message.readBy.where((id) => id != message.senderId).length;
  final receivers = {
    ...message.deliveredTo,
    ...message.readBy,
  }.where((id) => id != message.senderId).length;
  if (readers >= otherMembers) {
    return ReceiptState.read;
  }
  if (receivers >= otherMembers) {
    return ReceiptState.delivered;
  }
  return ReceiptState.sent;
}

/// Messages que je dois signaler comme reçus : venus d'un autre, visibles
/// par moi (groupe ou privé pour moi), pas encore signalés.
List<String> toMarkDelivered(List<ChatMessage> messages, String myId) => [
      for (final m in messages)
        if (m.id.isNotEmpty &&
            m.senderId != myId &&
            (m.recipientId == null || m.recipientId == myId) &&
            !m.deliveredTo.contains(myId) &&
            !m.readBy.contains(myId))
          m.id,
    ];

/// Messages affichés que je dois signaler comme lus.
List<String> toMarkRead(List<ChatMessage> messages, String myId) => [
      for (final m in messages)
        if (m.id.isNotEmpty &&
            m.senderId != myId &&
            (m.recipientId == null || m.recipientId == myId) &&
            !m.readBy.contains(myId) &&
            !(m.recipientId == myId && m.readAt != null))
          m.id,
    ];
