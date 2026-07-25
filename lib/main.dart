import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/firebase_push_service.dart';
import 'core/services/supabase_service.dart';
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
  await FirebasePushService.initialize();
  runApp(const ProviderScope(child: MdiBuildApp()));
}
