import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/chat_message.dart';
import '../../data/chat_repository.dart';
import '../../../projects/presentation/providers/selected_project_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final currentProjectMessagesProvider =
    StreamProvider<List<ChatMessage>>((ref) async* {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    yield const <ChatMessage>[];
    return;
  }

  yield* ref.read(chatRepositoryProvider).streamProjectMessages(project.id);
});
