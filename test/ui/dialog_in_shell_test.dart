import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Reproduit la structure de l'application : les écrans sont affichés dans
/// une coque (ShellRoute) qui possède son propre navigateur, alors que les
/// boîtes de dialogue s'ouvrent sur le navigateur racine.
///
/// Bug constaté (suppression d'un projet → écran noir, arrêt) : fermer la
/// boîte avec le contexte de la PAGE retirait la dernière page de la coque
/// (assertion go_router « currentConfiguration.isNotEmpty »).
Widget _app(Widget Function(BuildContext) page) {
  final router = GoRouter(
    initialLocation: '/projects',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/projects', builder: (c, s) => Builder(builder: page)),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<bool?> _confirm(BuildContext context, {required bool useDialogContext}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final navContext = useDialogContext ? dialogContext : context;
      return AlertDialog(
        title: const Text('Supprimer le projet'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(navContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(navContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      );
    },
  );
}

Widget _page(BuildContext context, {required bool useDialogContext}) {
  return Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => _confirm(context, useDialogContext: useDialogContext),
        child: const Text('Page Projets'),
      ),
    ),
  );
}

void main() {
  testWidgets('CORRIGÉ : fermer avec le contexte de la boîte garde la page',
      (tester) async {
    await tester.pumpWidget(_app((c) => _page(c, useDialogContext: true)));
    await tester.tap(find.text('Page Projets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le projet'), findsNothing);
    expect(find.text('Page Projets'), findsOneWidget);
  });
}

