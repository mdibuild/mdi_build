import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/user_role.dart';
import 'package:mdi_build/core/models/app_user.dart';
import 'package:mdi_build/core/models/chat_message.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/features/auth/presentation/login_page.dart';
import 'package:mdi_build/features/chat/data/chat_repository.dart';
import 'package:mdi_build/features/chat/presentation/chat_page.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/settings_providers.dart';
import 'package:mdi_build/shared/presentation/main_shell_page.dart';
import 'package:mdi_build/shared/presentation/premium_ui.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

ThemeData _theme(AppPaletteId id) {
  final palette = appPalettes[id]!;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

void _setScreen(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
}

/// Faux dépôt de chat en mémoire : reproduit la séparation chat général /
/// projet côté données et mémorise la destination de chaque envoi.
class _FakeChatRepository implements ChatRepository {
  final List<ChatMessage> _messages = [];
  final _changes = StreamController<void>.broadcast();
  final List<String?> sentProjectIds = [];
  var _seq = 0;

  void seed(String text, {String? projectId, String sender = 'u2'}) {
    _seq++;
    _messages.add(
      ChatMessage(
        id: 'm$_seq',
        companyId: 'c1',
        projectId: projectId,
        senderId: sender,
        senderName: sender == 'u1' ? 'Med Grine · Directeur' : 'Karim · Chef de projet',
        messageType: 'text',
        textContent: text,
        fileSize: 0,
        createdAt: DateTime(2026, 10, 18, 9, _seq),
        updatedAt: DateTime(2026, 10, 18, 9, _seq),
      ),
    );
    _changes.add(null);
  }

  Stream<List<ChatMessage>> _watch(bool Function(ChatMessage) keep) async* {
    yield _messages.where(keep).toList();
    await for (final _ in _changes.stream) {
      yield _messages.where(keep).toList();
    }
  }

  @override
  Stream<List<ChatMessage>> streamCompanyMessages(String companyId) =>
      _watch((m) => m.companyId == companyId);

  @override
  Stream<List<ChatMessage>> streamGeneralMessages(String companyId) =>
      _watch((m) => m.companyId == companyId && m.projectId == null);

  @override
  Stream<List<ChatMessage>> streamProjectMessages(String projectId) =>
      _watch((m) => m.projectId == projectId);

  @override
  Future<void> sendText({
    required String companyId,
    required String? projectId,
    required String senderId,
    required String senderName,
    required String text,
    String? recipientId,
    String? recipientName,
  }) async {
    sentProjectIds.add(projectId);
    seed(text, projectId: projectId, sender: senderId);
  }

  @override
  Future<void> sendBinaryMessage({
    required String companyId,
    required String? projectId,
    required String senderId,
    required String senderName,
    required String messageType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    int? audioDurationMs,
    String? recipientId,
    String? recipientName,
  }) async {}

  @override
  Future<void> deleteMessage(ChatMessage message) async {}

  @override
  Future<void> markRead(String messageId) async {}

  @override
  Future<void> editText({
    required String messageId,
    required String newText,
  }) async {}

  @override
  Future<String> createSignedUrl({
    required String bucketId,
    required String filePath,
    int expiresInSeconds = 3600,
  }) async =>
      'https://example.invalid/file';
}

const _projectA = Project(
  id: 'pA',
  companyId: 'c1',
  name: 'Villa Hydra',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

const _projectB = Project(
  id: 'pB',
  companyId: 'c1',
  name: 'Immeuble Oran',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

Widget _chatApp(_FakeChatRepository repo, {AppPaletteId palette = AppPaletteId.blueprintClair}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      currentProfileProvider.overrideWith(
        (ref) async => const AppUser(
          id: 'u1',
          companyId: 'c1',
          email: '',
          fullName: 'Med Grine',
          role: UserRole.directeur,
        ),
      ),
      projectsProvider.overrideWith((ref) async => [_projectA, _projectB]),
      companyUsersProvider('c1').overrideWith((ref) async => const []),
    ],
    child: MaterialApp(theme: _theme(palette), home: const ChatPage()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Le plugin d'enregistrement audio est créé à l'ouverture du chat.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  });

  group('Défilement en paysage (AdaptiveHeaderColumn)', () {
    Widget page(Widget body) => MaterialApp(
          theme: _theme(AppPaletteId.blueprintClair),
          home: Scaffold(appBar: AppBar(title: const Text('Test')), body: body),
        );

    List<Widget> header() => [
          for (var i = 0; i < 6; i++)
            SizedBox(height: 80, child: Text('En-tête $i')),
        ];

    Widget list() => Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 48, child: Text('Ligne $i')),
            ],
          ),
        );

    testWidgets('témoin : un Column classique déborde en paysage',
        (tester) async {
      _setScreen(tester, _landscape);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page(Column(children: [...header(), list()])));
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('sans débordement, en-tête et liste accessibles en paysage',
        (tester) async {
      _setScreen(tester, _landscape);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        page(AdaptiveHeaderColumn(children: [...header(), list()])),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ligne 0').hitTestable(), findsOneWidget);
      // Le bas de l'en-tête est atteignable en défilant l'en-tête.
      await tester.scrollUntilVisible(
        find.text('En-tête 5'),
        60,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('En-tête 5').hitTestable(), findsOneWidget);
      // Et la fin de la liste en défilant la liste.
      await tester.scrollUntilVisible(
        find.text('Ligne 39'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Ligne 39').hitTestable(), findsOneWidget);
    });

    testWidgets('portrait : rendu inchangé, en-tête entièrement visible',
        (tester) async {
      _setScreen(tester, const Size(390, 1400));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        page(AdaptiveHeaderColumn(children: [...header(), list()])),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 6; i++) {
        expect(find.text('En-tête $i').hitTestable(), findsOneWidget);
      }
    });
  });

  group('Écran de connexion', () {
    for (final entry in {
      'paysage': (_landscape, 0.0),
      'portrait + clavier': (_portrait, 330.0),
      'paysage + clavier': (_landscape, 200.0),
    }.entries) {
      testWidgets('${entry.key} : aucun débordement, bouton atteignable',
          (tester) async {
        _setScreen(tester, entry.value.$1, keyboard: entry.value.$2);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(AppPaletteId.blueprintClair),
            home: const LoginPage(),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Se connecter'),
          80,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Se connecter').hitTestable(), findsOneWidget);
      });
    }
  });

  testWidgets('rotation : la coque conserve l\'écran et la saisie en cours',
      (tester) async {
    var initCount = 0;
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShellPage(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  _ProbePage(onInit: () => initCount++),
            ),
          ],
        ),
      ],
    );

    _setScreen(tester, _portrait);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: _theme(AppPaletteId.blueprintClair),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'brouillon en cours');

    _setScreen(tester, _landscape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('brouillon en cours'), findsOneWidget);

    _setScreen(tester, _portrait);
    await tester.pumpAndSettle();
    expect(find.text('brouillon en cours'), findsOneWidget);
    expect(initCount, 1, reason: "l'écran ne doit pas être recréé");
  });

  group('Chat', () {
    testWidgets('historiques séparés : général / projet A / projet B',
        (tester) async {
      _setScreen(tester, _portrait);
      addTearDown(tester.view.reset);
      final repo = _FakeChatRepository()
        ..seed('Réunion chantier lundi', projectId: 'pA')
        ..seed('Livraison béton Oran', projectId: 'pB');

      await tester.pumpWidget(_chatApp(repo));
      await tester.pumpAndSettle();

      // Conversation projet A (projet sélectionné par défaut).
      expect(find.text('Villa Hydra'), findsWidgets);
      expect(find.textContaining('Réunion chantier lundi'), findsOneWidget);
      expect(find.textContaining('Livraison béton Oran'), findsNothing);

      // Envoi dans le projet A.
      await tester.enterText(find.byType(TextField).last, 'Message projet A');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(repo.sentProjectIds.last, 'pA');

      // Chat général : vide au départ, aucun message de projet.
      await tester.tap(find.text('Général'));
      await tester.pumpAndSettle();
      expect(find.text('Chat général'), findsOneWidget);
      expect(find.textContaining('Réunion chantier lundi'), findsNothing);
      expect(find.textContaining('Message projet A'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'Bonjour équipe');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(repo.sentProjectIds.last, isNull);
      expect(find.textContaining('Bonjour équipe'), findsOneWidget);

      // Changement de projet via le sélecteur de conversations : projet B.
      await tester.tap(find.text('Chat général')); // titre → sélecteur
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immeuble Oran').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Livraison béton Oran'), findsOneWidget);
      expect(find.textContaining('Réunion chantier lundi'), findsNothing);
      expect(find.textContaining('Bonjour équipe'), findsNothing);

      // Retour au général puis actualisation : le message est conservé.
      await tester.tap(find.text('Général'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonjour équipe'), findsOneWidget);
      expect(find.textContaining('Message projet A'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final entry in {
      'portrait': (_portrait, 0.0),
      'paysage': (_landscape, 0.0),
      'portrait + clavier': (_portrait, 330.0),
      'paysage + clavier': (_landscape, 200.0),
    }.entries) {
      testWidgets('${entry.key} : aucun débordement, saisie et envoi accessibles',
          (tester) async {
        _setScreen(tester, entry.value.$1, keyboard: entry.value.$2);
        addTearDown(tester.view.reset);
        final repo = _FakeChatRepository();
        for (var i = 0; i < 30; i++) {
          repo.seed(
            'Message numéro $i avec un peu de texte pour remplir la bulle',
            projectId: 'pA',
            sender: i.isEven ? 'u1' : 'u2',
          );
        }
        await tester.pumpWidget(_chatApp(repo, palette: AppPaletteId.ardoiseNuit));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Le dernier message est visible en bas, le champ et le bouton aussi.
        expect(find.textContaining('Message numéro 29').hitTestable(),
            findsOneWidget);
        expect(find.byType(TextField).last.hitTestable(), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'ok');
        await tester.pump();
        expect(find.byTooltip('Envoyer').hitTestable(), findsOneWidget);
      });
    }
  });
}

class _ProbePage extends StatefulWidget {
  const _ProbePage({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sonde')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _controller),
      ),
    );
  }
}
