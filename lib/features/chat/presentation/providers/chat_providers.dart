import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/chat_message.dart';
import '../../data/chat_repository.dart';
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
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref
      .read(chatRepositoryProvider)
      .streamGeneralMessages(profile.companyId);
});
