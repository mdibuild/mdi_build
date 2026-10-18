import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/user_role.dart';
import 'package:mdi_build/core/models/app_user.dart';
import 'package:mdi_build/core/models/chat_message.dart';
import 'package:mdi_build/core/services/push_navigation.dart';
import 'package:mdi_build/features/chat/domain/chat_unread.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/shared/presentation/main_shell_page.dart';

ChatMessage _msg(String id, String sender, DateTime at, {String? projectId, String? recipient}) =>
    ChatMessage(
      id: id,
      companyId: 'c1',
      projectId: projectId,
      senderId: sender,
      senderName: 'X',
      messageType: 'text',
      textContent: 'msg $id',
      fileSize: 0,
      recipientId: recipient,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  group('Toucher une notification → bon module', () {
    test('route selon le type envoyé par le serveur', () {
      expect(routeForPushData({'type': 'chat'}), '/chat');
      expect(routeForPushData({'type': 'achats'}), '/achats');
      expect(routeForPushData({'type': 'planning'}), '/planning');
      expect(routeForPushData({'type': 'task_deadline', 'taskId': 't1'}), '/planning');
      expect(routeForPushData({}), '/dashboard');
      expect(moduleForPushData({'type': 'task_deadline'}), 'planning');
    });

    test('notification touchée avant que l’appli soit prête : traitée ensuite', () async {
      final opened = <Map<String, dynamic>>[];
      PushNavigation.open({'type': 'chat', 'conversation': 'general'});
      PushNavigation.attach((data) async => opened.add(data));
      expect(opened.single['type'], 'chat');
      PushNavigation.open({'type': 'achats'});
      expect(opened.last['type'], 'achats');
    });
  });

  group('Messages non lus', () {
    final base = DateTime.utc(2026, 10, 18, 10);
    final messages = [
      _msg('old', 'u2', base.subtract(const Duration(hours: 1))), // avant référence
      _msg('g1', 'u2', base.add(const Duration(minutes: 1))),
      _msg('g2', 'u2', base.add(const Duration(minutes: 2))),
      _msg('mine', 'u1', base.add(const Duration(minutes: 3))), // le mien
      _msg('p1', 'u2', base.add(const Duration(minutes: 4)), projectId: 'pA'),
      _msg('priv-moi', 'u2', base.add(const Duration(minutes: 5)), recipient: 'u1'),
      _msg('priv-autre', 'u2', base.add(const Duration(minutes: 6)), recipient: 'u3'),
    ];

    test('ne compte ni mes messages, ni l’historique, ni les privés des autres', () {
      final counts = unreadByConversation(
        messages: messages,
        myId: 'u1',
        lastSeen: const {},
        baseline: base,
      );
      expect(counts, {'general': 3, 'pA': 1}); // g1, g2, priv-moi ; p1
    });

    test('dernier passage dans une conversation : remise à zéro', () {
      final counts = unreadByConversation(
        messages: messages,
        myId: 'u1',
        lastSeen: {'general': base.add(const Duration(minutes: 5))},
        baseline: base,
      );
      expect(counts['general'], isNull);
      expect(counts['pA'], 1);
    });
  });

  testWidgets('pastille rouge sur le menu Chat avec le nombre de non-lus', (tester) async {
    SharedPreferences.setMockInitialValues({
      'chat_read_baseline': DateTime.utc(2026, 1, 1).microsecondsSinceEpoch,
    });
    final now = DateTime.utc(2026, 10, 18, 9);
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShellPage(child: child),
          routes: [
            GoRoute(path: '/dashboard', builder: (c, s) => const Scaffold(body: Text('Accueil'))),
          ],
        ),
      ],
    );
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1200, 800) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => const AppUser(
              id: 'u1', companyId: 'c1', email: '', fullName: 'Med', role: UserRole.directeur)),
          companyChatMessagesProvider.overrideWith((ref) => Stream.value([
                _msg('a', 'u2', now),
                _msg('b', 'u2', now.add(const Duration(minutes: 1))),
                _msg('c', 'u3', now.add(const Duration(minutes: 2)), projectId: 'pA'),
              ])),
        ],
        child: MaterialApp.router(
          theme: ThemeData(extensions: [
            resolvePaletteColors(appPalettes[AppPaletteId.blueprintClair]!, 0),
          ]),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget); // pastille sur « Chat »
  });
}
