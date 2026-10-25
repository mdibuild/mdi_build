import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/chat_message.dart';
import '../../data/chat_repository.dart';
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

/// Messages du projet sélectionné uniquement.
final currentProjectMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  ref.watch(moduleRefreshRevisionProvider);
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref.read(chatRepositoryProvider).streamProjectMessages(project.id);
});

/// Messages du chat général (sans projet) de l'entreprise de l'utilisateur.
final generalChatMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref
      .read(chatRepositoryProvider)
      .streamGeneralMessages(profile.companyId);
});

// ---------------------------------------------------------------------------
// Messages non lus
// ---------------------------------------------------------------------------

/// Tous les messages de l'entreprise, en temps réel (compteurs de non-lus).
final companyChatMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  ref.watch(moduleRefreshRevisionProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    yield const <ChatMessage>[];
    return;
  }
  yield* ref
      .read(chatRepositoryProvider)
      .streamCompanyMessages(profile.companyId);
});

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
