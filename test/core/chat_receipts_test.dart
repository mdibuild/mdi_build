import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/models/chat_message.dart';
import 'package:mdi_build/features/chat/domain/chat_receipts.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';

ChatMessage _m(
  String id, {
  String sender = 'me',
  String? to,
  String? project,
  String type = 'text',
  DateTime? deliveredAt,
  DateTime? readAt,
  List<String> deliveredTo = const [],
  List<String> readBy = const [],
  int minute = 0,
}) =>
    ChatMessage(
      id: id,
      companyId: 'c1',
      projectId: project,
      senderId: sender,
      senderName: sender,
      messageType: type,
      textContent: id,
      fileSize: 0,
      recipientId: to,
      createdAt: DateTime(2026, 10, 28, 9, minute),
      updatedAt: DateTime(2026, 10, 28, 9, minute),
      deliveredAt: deliveredAt,
      readAt: readAt,
      deliveredTo: deliveredTo,
      readBy: readBy,
    );

void main() {
  group('Accusés ✓ / ✓✓ / ✓✓ bleu', () {
    test('privé : envoyé, reçu, lu — quel que soit le type', () {
      for (final type in ['text', 'image', 'audio', 'file']) {
        expect(receiptFor(_m('a', to: 'u2', type: type), otherMembers: 3),
            ReceiptState.sent);
        expect(
            receiptFor(
                _m('a', to: 'u2', type: type, deliveredAt: DateTime(2026)),
                otherMembers: 3),
            ReceiptState.delivered);
        expect(
            receiptFor(_m('a', to: 'u2', type: type, readAt: DateTime(2026)),
                otherMembers: 3),
            ReceiptState.read);
      }
    });

    test('groupe : reçu puis lu par tous les autres membres', () {
      expect(receiptFor(_m('g', type: 'image'), otherMembers: 2),
          ReceiptState.sent);
      expect(
          receiptFor(_m('g', type: 'audio', deliveredTo: ['u2']),
              otherMembers: 2),
          ReceiptState.sent);
      expect(
          receiptFor(_m('g', type: 'audio', deliveredTo: ['u2', 'u3']),
              otherMembers: 2),
          ReceiptState.delivered);
      expect(
          receiptFor(_m('g', deliveredTo: ['u2', 'u3'], readBy: ['u2']),
              otherMembers: 2),
          ReceiptState.delivered);
      expect(receiptFor(_m('g', readBy: ['u2', 'u3']), otherMembers: 2),
          ReceiptState.read);
    });

    test('messages à signaler reçus / lus', () {
      final list = [
        _m('mine'),
        _m('group', sender: 'u2'),
        _m('pour-moi', sender: 'u2', to: 'me'),
        _m('pour-autre', sender: 'u2', to: 'u3'),
        _m('deja-recu', sender: 'u2', deliveredTo: ['me']),
        _m('deja-lu', sender: 'u2', readBy: ['me']),
      ];
      expect(toMarkDelivered(list, 'me'), ['group', 'pour-moi']);
      expect(toMarkRead(list, 'me'), ['group', 'pour-moi', 'deja-recu']);
    });
  });

  test('« Tous les projets » : regroupement par personne, sans perte', () {
    final all = [
      _m('1', sender: 'u2', project: 'pA', minute: 3),
      _m('2', sender: 'me', to: 'u2', minute: 1),
      _m('3', sender: 'u2', to: 'me', project: 'pB', minute: 2),
      _m('4', sender: 'u3', project: 'pA', minute: 4),
      _m('5', sender: 'u3', to: 'u2', minute: 5), // privé entre deux autres
    ];
    expect(messagesForPeer(all, myId: 'me', peerId: null).map((m) => m.id),
        ['2', '3', '1', '4']);
    expect(messagesForPeer(all, myId: 'me', peerId: 'u2').map((m) => m.id),
        ['2', '3', '1']);
    expect(
        messagesForPeer(all, myId: 'me', peerId: 'u3').map((m) => m.id), ['4']);
  });
}
