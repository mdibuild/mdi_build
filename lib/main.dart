import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // Les notifications push (Firebase Messaging + notifications locales) ne
  // sont pas prises en charge sur le web : on les active uniquement hors
  // navigateur, pour éviter un plantage au démarrage dans Chrome/Edge.
  if (!kIsWeb) {
    await FirebasePushService.initialize();
    unawaited(DeviceTokenService.registerCurrentToken());
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
