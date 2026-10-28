import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/chat_message.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_receipts.dart';
import '../../domain/chat_unread.dart';
import '../../../projects/presentation/providers/current_profile_provider.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

/// Conversation ouverte dans le module chat : chat général de l'entreprise,
/// ou chat du projet sélectionné. Conservé tant que l'appli est ouverte
/// (changement d'écran, rotation…).
enum ChatConversation { general, project }

class ChatConversationNotifier extends Notifier<ChatConversation> {
  @override
  ChatConversation build() => ChatConversation.project;

  void open(ChatConversation conversation) => state = conversation;
}

final chatConversationProvider =
    NotifierProvider<ChatConversationNotifier, ChatConversation>(
  ChatConversationNotifier.new,
);

/// Identifiant du projet sélectionné : le flux ne redémarre que si le
/// projet change (pas à chaque actualisation des autres modules).
final _selectedProjectIdForChat = Provider<String?>(
    (ref) => ref.watch(selectedProjectProvider.select((p) => p.value?.id)));

/// Entreprise de l'utilisateur, même principe.
final _companyIdForChat = Provider<String?>((ref) =>
    ref.watch(currentProfileProvider.select((p) => p.value?.companyId)));

/// Messages du projet sélectionné uniquement. Le temps réel suffit à les
/// tenir à jour : pas de reconnexion à chaque actualisation de l'appli.
final currentProjectMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  final projectId = ref.watch(_selectedProjectIdForChat);
  if (projectId == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref.read(chatRepositoryProvider).streamProjectMessages(projectId);
});

/// Messages du chat général (sans projet) de l'entreprise de l'utilisateur.
final generalChatMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  final companyId = ref.watch(_companyIdForChat);
  if (companyId == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref.read(chatRepositoryProvider).streamGeneralMessages(companyId);
});

// ---------------------------------------------------------------------------
// Messages non lus
// ---------------------------------------------------------------------------

/// Tous les messages de l'entreprise, en temps réel (compteurs de non-lus).
final companyChatMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  final companyId = ref.watch(_companyIdForChat);
  if (companyId == null) {
    yield const <ChatMessage>[];
    return;
  }
  yield* ref.read(chatRepositoryProvider).streamCompanyMessages(companyId);
});

/// Vue « Tous les projets » : conversation avec une personne (null = tous
/// les messages, tous projets et chat général confondus).
class ChatPeerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? peerId) => state = peerId;
}

final chatPeerProvider =
    NotifierProvider<ChatPeerNotifier, String?>(ChatPeerNotifier.new);

/// Messages de la vue « Tous les projets », triés : tous ceux qui me sont
/// visibles, ou ceux échangés avec [peerId] (ses messages de groupe, nos
/// messages privés dans les deux sens).
List<ChatMessage> messagesForPeer(
  List<ChatMessage> all, {
  required String? myId,
  required String? peerId,
}) {
  bool visible(ChatMessage m) =>
      m.recipientId == null || m.recipientId == myId || m.senderId == myId;
  final list = all.where((m) {
    if (!visible(m)) {
      return false;
    }
    if (peerId == null) {
      return true;
    }
    final privateBetweenUs = (m.senderId == myId && m.recipientId == peerId) ||
        (m.senderId == peerId && m.recipientId == myId);
    final peerPublic = m.senderId == peerId && m.recipientId == null;
    return privateBetweenUs || peerPublic;
  }).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return list;
}

/// Messages « Tous les projets » (filtrés selon la personne choisie).
final peerChatMessagesProvider = Provider<AsyncValue<List<ChatMessage>>>((ref) {
  final myId = ref.watch(currentProfileProvider.select((p) => p.value?.id));
  final peerId = ref.watch(chatPeerProvider);
  return ref.watch(companyChatMessagesProvider).whenData(
        (all) => messagesForPeer(all, myId: myId, peerId: peerId),
      );
});

/// Accusés « reçu » : dès qu'un message arrive sur ce téléphone (appli
/// ouverte, quel que soit l'écran), il est signalé à l'expéditeur.
final chatDeliverySyncProvider = Provider<void>((ref) {
  final myId = ref.watch(currentProfileProvider.select((p) => p.value?.id));
  final messages = ref.watch(companyChatMessagesProvider).value;
  if (myId == null || messages == null) {
    return;
  }
  final ids = toMarkDelivered(messages, myId)
      .where(_deliveredSent.add) // une seule fois par message
      .toList();
  if (ids.isEmpty) {
    return;
  }
  Future(() async {
    try {
      await ref.read(chatRepositoryProvider).markDelivered(ids);
    } catch (_) {
      // Base sans accusés (script SQL v2.4) : nouvel essai plus tard.
      _deliveredSent.removeAll(ids);
    }
  });
});

final Set<String> _deliveredSent = <String>{};

/// Dernier passage de l'utilisateur dans chaque conversation, conservé sur
/// l'appareil. [baseline] : date de première utilisation (l'historique
/// antérieur n'est pas compté comme non lu).
class ChatReadState {
  const ChatReadState({required this.baseline, required this.lastSeen});

  final DateTime baseline;
  final Map<String, DateTime> lastSeen;
}

class ChatReadStateNotifier extends AsyncNotifier<ChatReadState> {
  static const _baselineKey = 'chat_read_baseline';
  static const _lastSeenKey = 'chat_read_last_seen';

  /// Les dates des messages sont enregistrées par l'application à l'heure
  /// locale (sans fuseau) puis relues comme UTC : on utilise la même
  /// convention pour pouvoir les comparer.
  static DateTime _nowSameConvention() {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day, n.hour, n.minute, n.second);
  }

  @override
  Future<ChatReadState> build() async {
    final prefs = await SharedPreferences.getInstance();
    var baselineMicros = prefs.getInt(_baselineKey);
    if (baselineMicros == null) {
      baselineMicros = _nowSameConvention().microsecondsSinceEpoch;
      await prefs.setInt(_baselineKey, baselineMicros);
    }
    final lastSeen = <String, DateTime>{};
    final raw = prefs.getString(_lastSeenKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) {
          lastSeen[k] = DateTime.fromMicrosecondsSinceEpoch(
            (v as num).toInt(),
            isUtc: true,
          );
        });
      } catch (_) {
        // Données illisibles : on repart de la date de référence.
      }
    }
    return ChatReadState(
      baseline:
          DateTime.fromMicrosecondsSinceEpoch(baselineMicros, isUtc: true),
      lastSeen: lastSeen,
    );
  }

  /// Marque la conversation comme lue jusqu'au message [latest] inclus.
  Future<void> markSeen(String conversationKey, DateTime latest) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final previous = current.lastSeen[conversationKey];
    if (previous != null && !latest.isAfter(previous)) {
      return;
    }
    final next = {...current.lastSeen, conversationKey: latest};
    state =
        AsyncData(ChatReadState(baseline: current.baseline, lastSeen: next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastSeenKey,
      jsonEncode({
        for (final e in next.entries) e.key: e.value.microsecondsSinceEpoch,
      }),
    );
  }
}

final chatReadStateProvider =
    AsyncNotifierProvider<ChatReadStateNotifier, ChatReadState>(
  ChatReadStateNotifier.new,
);

/// Non-lus par conversation (`general` ou identifiant de projet).
final chatUnreadByConversationProvider = Provider<Map<String, int>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  final messages = ref.watch(companyChatMessagesProvider).value;
  final read = ref.watch(chatReadStateProvider).value;
  if (profile == null || messages == null || read == null) {
    return const {};
  }
  return unreadByConversation(
    messages: messages,
    myId: profile.id,
    lastSeen: read.lastSeen,
    baseline: read.baseline,
  );
});

/// Total des messages non lus, toutes conversations (pastille rouge).
final chatUnreadTotalProvider = Provider<int>((ref) {
  return ref
      .watch(chatUnreadByConversationProvider)
      .values
      .fold<int>(0, (sum, n) => sum + n);
});
