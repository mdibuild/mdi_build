import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/purchase.dart';
import 'package:mdi_build/core/models/purchase_item.dart';
import 'package:mdi_build/core/models/purchase_workflow.dart';
import 'package:mdi_build/core/providers/navigation_history.dart';
import 'package:mdi_build/features/achats/data/purchases_repository.dart';
import 'package:mdi_build/features/achats/presentation/achats_page.dart';
import 'package:mdi_build/features/achats/presentation/purchase_tracking.dart';
import 'package:mdi_build/features/achats/presentation/providers/purchases_providers.dart';
import 'package:mdi_build/features/documents/presentation/providers/documents_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';

const _project = Project(
  id: 'alpha',
  companyId: 'company',
  name: 'Projet Alpha',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

ThemeData _theme() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

class _PurchasesRepository implements PurchasesRepository {
  @override
  Future<List<PurchaseItem>> fetchPurchaseItems(String purchaseId) async => [
        PurchaseItem(
          id: 'i1',
          purchaseId: purchaseId,
          article: 'Ciment CPJ 42,5',
          description: '',
          quantity: 20,
          unit: 'sac',
          unitPrice: 900,
          notes: '',
          sortOrder: 0,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      ];

  @override
  Future<List<PurchaseEvent>> fetchEvents(String purchaseId) async => [
        PurchaseEvent(
          id: 'e1',
          purchaseId: purchaseId,
          kind: 'creation',
          createdAt: DateTime(2026, 10, 1, 9),
          actorName: 'Chef de projet',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Purchase _purchase(String id) => Purchase.fromMap({
      'id': id,
      'company_id': 'company',
      'project_id': 'alpha',
      'title': 'Commande $id',
      'lot': 'Gros œuvre',
      'status': 'en_traitement',
      'order_number': null,
      'created_at': '2026-10-01T09:00:00Z',
      'updated_at': '2026-10-01T09:00:00Z',
    });

Future<void> _scrollTo(WidgetTester tester, String text) =>
    tester.scrollUntilVisible(find.text(text), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last);

void main() {
  test('historique : retour à l’écran précédent, sans aller-retour infini', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final history = container.read(navigationHistoryProvider.notifier);
    history.visit('/dashboard');
    history.visit('/achats');
    history.visit('/devis');
    expect(history.previous, '/achats');
    history.visit('/achats'); // retour
    expect(
        container.read(navigationHistoryProvider), ['/dashboard', '/achats']);
    history.visit('/login');
    expect(container.read(navigationHistoryProvider), isEmpty);
  });

  for (final size in const [Size(390, 844), Size(1400, 1000)]) {
    testWidgets(
        'Achats : un appui ouvre la fiche en plein écran, fermer revient à la '
        'liste (${size.width.toInt()})', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(overrides: [
        projectsProvider.overrideWith((ref) async => [_project]),
        selectedProjectProvider.overrideWith((ref) async => _project),
        activePurchasesProvider
            .overrideWith((ref) async => [_purchase('A'), _purchase('B')]),
        archivedPurchasesProvider.overrideWith((ref) async => []),
        activeSuppliersProvider.overrideWith((ref) async => []),
        archivedSuppliersProvider.overrideWith((ref) async => []),
        purchasesRepositoryProvider.overrideWithValue(_PurchasesRepository()),
        for (final id in ['A', 'B'])
          purchaseDocumentsProvider(id).overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: _theme(), home: const AchatsPage()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Commande A'), findsOneWidget);
      await _scrollTo(tester, 'Commande B');
      expect(find.text('Commande B'), findsOneWidget);
      await _scrollTo(tester, 'Commande A');
      await tester.tap(find.text('Commande A'));
      await tester.pumpAndSettle();

      // Fiche plein écran : la liste n'est plus visible.
      expect(find.text('Commande B'), findsNothing);
      expect(find.text('Informations'), findsOneWidget);
      for (final section in ['Articles', 'Suivi']) {
        await _scrollTo(tester, section);
        expect(find.text(section), findsOneWidget);
      }
      expect(find.text('Ciment CPJ 42,5'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.textContaining('Chef de projet'), 200,
          scrollable: find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .last);
      expect(find.textContaining('Chef de projet'), findsOneWidget);
      expect(find.text('Commander'), findsWidgets);
      // Revenir en arrière : bouton dédié et étapes cliquables.
      expect(find.textContaining('Revenir à « Validé DG »'), findsOneWidget);
      // Remonter en haut de la fiche, jusqu'à la barre d'étapes.
      await tester.fling(
          find.byType(ListView).last, const Offset(0, 3000), 3000);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(PurchaseStepper),
          matching: find.text('Besoin émis')));
      await tester.pumpAndSettle();
      expect(find.text('Revenir à « Besoin émis » ?'), findsOneWidget);
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Commande A'), findsOneWidget);
      await _scrollTo(tester, 'Commande B');
      expect(find.text('Commande B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bouton Retour dans les modules et retour Android',
      (tester) async {
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      for (final path in ['/dashboard', '/achats', '/devis'])
        GoRoute(
          path: path,
          builder: (_, __) => ProjectModuleScaffold(
            appBar: AppBar(title: Text('Module $path')),
            body: const SizedBox.shrink(),
          ),
        ),
    ]);
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: [
      projectsProvider.overrideWith((ref) async => [_project]),
      selectedProjectProvider.overrideWith((ref) async => _project),
    ]);
    addTearDown(container.dispose);
    final history = container.read(navigationHistoryProvider.notifier);
    router.routerDelegate.addListener(() => history
        .visit(router.routerDelegate.currentConfiguration.uri.toString()));
    history.visit('/dashboard');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: _theme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.go('/achats');
    await tester.pumpAndSettle();
    router.go('/devis');
    await tester.pumpAndSettle();
    expect(find.text('Module /devis'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Module /achats'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Module /dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
