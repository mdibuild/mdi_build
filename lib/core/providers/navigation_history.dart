import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Historique des écrans visités dans l'application (les modules sont
/// ouverts par remplacement, sans pile de navigation) : sert au bouton
/// « Retour » de chaque module et au bouton retour d'Android.
class NavigationHistory extends Notifier<List<String>> {
  static const _max = 30;

  @override
  List<String> build() => const [];

  /// Enregistre l'écran affiché. Revenir sur l'avant-dernier écran est
  /// compris comme un retour (pas d'aller-retour infini).
  void visit(String location) {
    if (location.isEmpty || location == '/login') {
      state = const [];
      return;
    }
    final list = [...state];
    if (list.isNotEmpty && list.last == location) {
      return;
    }
    if (list.length >= 2 && list[list.length - 2] == location) {
      list.removeLast();
    } else {
      list.add(location);
      if (list.length > _max) {
        list.removeAt(0);
      }
    }
    state = list;
  }

  /// Écran précédent, ou null.
  String? get previous => state.length >= 2 ? state[state.length - 2] : null;

  /// Revient à l'écran précédent (à défaut, au tableau de bord). Renvoie
  /// false s'il n'y a nulle part où revenir.
  bool back(GoRouter router) {
    final target = previous;
    if (target != null) {
      router.go(target);
      return true;
    }
    final current = state.isEmpty ? '' : state.last;
    if (!current.startsWith('/dashboard')) {
      router.go('/dashboard');
      return true;
    }
    return false;
  }
}

final navigationHistoryProvider =
    NotifierProvider<NavigationHistory, List<String>>(NavigationHistory.new);

/// Bouton « Retour » des modules : ferme d'abord un écran ouvert par-dessus
/// (fiche, formulaire), sinon revient au module précédent.
class ModuleBackButton extends ConsumerWidget {
  const ModuleBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(navigationHistoryProvider);
    final atHome = history.length < 2 &&
        (history.isEmpty || history.last.startsWith('/dashboard'));
    return IconButton(
      tooltip: 'Retour',
      icon: const Icon(Icons.arrow_back),
      onPressed: atHome
          ? null
          : () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
                return;
              }
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                ref.read(navigationHistoryProvider.notifier).back(router);
              }
            },
    );
  }
}
