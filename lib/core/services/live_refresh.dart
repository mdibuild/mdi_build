import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/module_refresh_provider.dart';
import 'supabase_service.dart';

/// Tables suivies en temps réel : toute nouvelle entrée (ou modification,
/// suppression) actualise automatiquement les écrans ouverts.
const liveRefreshTables = [
  'projects',
  'spaces',
  'space_openings',
  'project_quotes',
  'project_quote_items',
  'project_invoices',
  'project_invoice_items',
  'purchases',
  'purchase_items',
  'project_tasks',
  'project_task_dependencies',
  'project_documents',
  'project_reports',
  'clients',
  'suppliers',
  'checklist_items',
];

/// Regroupe une rafale de changements (un devis = un en-tête + N lignes)
/// en une seule actualisation.
class LiveRefreshDebouncer {
  LiveRefreshDebouncer(this.onFire,
      {this.delay = const Duration(milliseconds: 700)});

  final VoidCallback onFire;
  final Duration delay;
  Timer? _timer;

  void ping() {
    _timer?.cancel();
    _timer = Timer(delay, onFire);
  }

  void dispose() => _timer?.cancel();
}

/// Écoute la base pendant que l'utilisateur est connecté et relance la
/// lecture des données des modules (filtres et saisies conservés).
class LiveRefreshScope extends ConsumerStatefulWidget {
  const LiveRefreshScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveRefreshScope> createState() => _LiveRefreshScopeState();
}

class _LiveRefreshScopeState extends ConsumerState<LiveRefreshScope> {
  RealtimeChannel? _channel;
  late final LiveRefreshDebouncer _debouncer = LiveRefreshDebouncer(() {
    if (mounted) {
      ref.read(moduleRefreshRevisionProvider.notifier).refresh();
    }
  });

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    try {
      final client = SupabaseService.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }
      final channel = client.channel('mdi-live-${user.id}');
      for (final table in liveRefreshTables) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _debouncer.ping(),
        );
      }
      _channel = channel..subscribe();
    } catch (error) {
      // Hors connexion ou Supabase non initialisé (tests) : le bouton
      // Actualiser reste disponible.
      debugPrint('Actualisation automatique indisponible : $error');
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    final channel = _channel;
    if (channel != null) {
      try {
        SupabaseService.client.removeChannel(channel);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
