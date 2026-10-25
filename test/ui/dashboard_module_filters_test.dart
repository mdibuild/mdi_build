import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/dashboard_metrics.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/features/dashboard/presentation/dashboard_page.dart';
import 'package:mdi_build/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/shared/presentation/module_filters.dart';
import 'package:mdi_build/shared/presentation/premium_ui.dart';

const _project = Project(
  id: 'dashboard-project',
  companyId: 'company',
  name: 'Résidence des Oliviers',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

const _metrics = DashboardMetrics(
  projectsCount: 3,
  tasksCount: 10,
  doneTasksCount: 4,
  lateTasksCount: 2,
  quotesCount: 7,
  purchasesCount: 8,
  reportsCount: 9,
  documentsCount: 11,
  autoReportsCount: 6,
  manualReportsCount: 3,
  recentReportTitles: ['Rapport coffrage', 'Rapport livraison'],
  highlights: ['Retard coffrage', 'Livraison à confirmer'],
);

ThemeData _theme() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ThemeData(
    useMaterial3: true,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

Widget _app({GoRouter? router}) => ProviderScope(
      overrides: [
        selectedProjectProvider.overrideWith((ref) async => _project),
        dashboardMetricsProvider.overrideWith((ref) async => _metrics),
      ],
      child: router == null
          ? MaterialApp(theme: _theme(), home: const DashboardPage())
          : MaterialApp.router(theme: _theme(), routerConfig: router),
    );

Finder _search() => find.descendant(
      of: find.byType(ModuleFilterBar),
      matching: find.byType(TextField),
    );

void main() {
  testWidgets(
      'dashboard : recherche et vue masquent les sections sans modifier les chiffres',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(_search(), 'Tâches');
    await tester.pumpAndSettle();
    final tile =
        tester.widget<PremiumMetricTile>(find.byType(PremiumMetricTile));
    expect(tile.label, 'Tâches');
    expect(tile.value, '10');
    expect(find.text('4 résultats'), findsOneWidget);
    expect(find.text('Rapports récents'), findsNothing);

    await tester.enterText(_search(), 'coffrage');
    await tester.pumpAndSettle();
    expect(find.byType(PremiumMetricTile), findsNothing);
    expect(find.text('2 résultats'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rapport coffrage'), 250,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    expect(find.text('Rapport coffrage'), findsOneWidget);
    expect(find.text('Rapport livraison'), findsNothing);
    expect(find.text('Vue exécutive'), findsNothing);

    await tester.scrollUntilVisible(_search(), -250,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.enterText(_search(), 'inexistant');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour ces filtres.'), findsOneWidget);
    await tester.ensureVisible(find.text('Réinitialiser'));
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ModuleFilterDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activité et rapports').last);
    await tester.pumpAndSettle();
    expect(find.byType(PremiumMetricTile), findsNothing);
    expect(find.text('4 résultats'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rapports récents'), 250,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    expect(find.text('Rapports récents'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Réinitialiser'), -250,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumMetricTile), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dashboard : les statuts ouvrent le planning et les rapports du projet courant',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    Widget destination(String module) => Consumer(builder: (context, ref, _) {
          final project = ref.watch(selectedProjectProvider).value;
          return Scaffold(body: Text('$module · ${project?.name}'));
        });
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/planning', builder: (_, __) => destination('Planning')),
      GoRoute(path: '/reports', builder: (_, __) => destination('Rapports')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tâches en retard'));
    await tester.tap(find.text('Tâches en retard'));
    await tester.pumpAndSettle();
    expect(find.text('Planning · Résidence des Oliviers'), findsOneWidget);
    router.go('/dashboard');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rapports automatiques'));
    await tester.tap(find.text('Rapports automatiques'));
    await tester.pumpAndSettle();
    expect(find.text('Rapports · Résidence des Oliviers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
