import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/device_token_service.dart';
import 'core/services/firebase_push_service.dart';
import 'core/services/supabase_service.dart';
import 'features/settings/presentation/providers/palette_providers.dart';
import 'firebase_options.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SupabaseService.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
  // Notifications push (Firebase Messaging + notifications locales) :
  // configurées uniquement pour Android et iPhone (ni web, ni ordinateur).
  // Un échec ne doit jamais empêcher l'application de démarrer.
  final pushSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (pushSupported) {
    try {
      await FirebasePushService.initialize();
      unawaited(DeviceTokenService.registerCurrentToken());
    } catch (error) {
      debugPrint('Notifications indisponibles : $error');
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final initialPaletteSelection = PaletteSelection.fromPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        paletteSelectionProvider.overrideWith(
          () => PaletteSelectionNotifier(initialPaletteSelection),
        ),
      ],
      child: const MdiBuildApp(),
    ),
  );
}
