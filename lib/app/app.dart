import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/providers/palette_providers.dart';
import 'router/app_router.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';

class MdiBuildApp extends ConsumerWidget {
  const MdiBuildApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
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
