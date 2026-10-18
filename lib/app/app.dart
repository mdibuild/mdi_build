import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/firebase_push_service.dart';
import '../core/services/push_navigation.dart';
import '../features/chat/presentation/providers/chat_providers.dart';
import '../features/projects/presentation/providers/selected_project_provider.dart';
import '../features/settings/presentation/providers/palette_providers.dart';
import 'router/app_router.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';

class MdiBuildApp extends ConsumerStatefulWidget {
  const MdiBuildApp({super.key});

  @override
  ConsumerState<MdiBuildApp> createState() => _MdiBuildAppState();
}

class _MdiBuildAppState extends ConsumerState<MdiBuildApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    // Après le premier affichage : la navigation est prête, une notification
    // touchée au lancement (ou plus tard) ouvre l'écran correspondant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PushNavigation.attach(_openFromNotification);
      }
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onLocationChanged);
    super.dispose();
  }

  /// Ouvre le module de la notification ; pour le chat, la bonne
  /// conversation (générale ou du projet concerné).
  Future<void> _openFromNotification(Map<String, dynamic> data) async {
    final router = ref.read(appRouterProvider);
    if ((data['type'] ?? '').toString() == 'chat') {
      final conversation = (data['conversation'] ?? '').toString();
      final projectId = (data['projectId'] ?? '').toString();
      final chat = ref.read(chatConversationProvider.notifier);
      if (conversation == 'general') {
        chat.open(ChatConversation.general);
      } else if (projectId.isNotEmpty) {
        await ref
            .read(selectedProjectIdProvider.notifier)
            .setProjectId(projectId);
        chat.open(ChatConversation.project);
      }
    }
    router.go(routeForPushData(data));
  }

  /// Suit l'écran affiché : pas de notification pour le module en cours de
  /// consultation, et son compteur est remis à zéro à l'ouverture.
  void _onLocationChanged() {
    final router = _router;
    if (router == null) {
      return;
    }
    final location =
        router.routerDelegate.currentConfiguration.uri.path;
    FirebasePushService.currentLocation = location;
    if (kIsWeb) {
      return;
    }
    for (final entry in const {
      '/chat': 'chat',
      '/achats': 'achats',
      '/planning': 'planning',
    }.entries) {
      if (location.startsWith(entry.key)) {
        FirebasePushService.clearModule(entry.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onLocationChanged);
      _router = router..routerDelegate.addListener(_onLocationChanged);
    }
    final selection = ref.watch(paletteSelectionProvider);
    final palette = appPalettes[selection.paletteId]!;
    final theme = AppTheme.build(
      palette,
      selection.accentIndex,
      titleColorIndex: selection.titleColorIndex,
      textColorIndex: selection.textColorIndex,
      highlightColorIndex: selection.highlightColorIndex,
      fontId: selection.fontId,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MDI Build',
      theme: theme,
      darkTheme: theme,
      themeMode:
          palette.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
