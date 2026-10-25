import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/space_type.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_quote.dart';
import 'package:mdi_build/core/models/space_item.dart';
import 'package:mdi_build/features/devis/presentation/devis_list_page.dart';
import 'package:mdi_build/features/devis/presentation/providers/devis_providers.dart';
import 'package:mdi_build/features/metrage/presentation/metrage_page.dart';
import 'package:mdi_build/features/metrage/presentation/providers/spaces_providers.dart';
import 'package:mdi_build/features/projects/presentation/projects_page.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/quantitatif/presentation/quantitatif_page.dart';
import 'package:mdi_build/shared/presentation/module_filters.dart';

const _project = Project(
  id: 'p1',
  companyId: 'c1',
  name: 'Chantier A',
  clientName: 'Client A',
  location: 'Alger',
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

SpaceItem _space(
  int number, {
  String? name,
  String level = 'RDC',
  SpaceType type = SpaceType.piece,
  RecordStatus status = RecordStatus.brouillon,
}) =>
    SpaceItem(
      id: 's$number',
      companyId: 'c1',
      projectId: 'p1',
      type: type,
      name: name ?? 'Pièce $number',
      levelName: level,
      length: number.toDouble(),
      width: 2,
      height: 3,
      quantity: 1,
      status: status,
    );

ProjectQuote _quote(String id, String title,
        {String status = 'brouillon', String mode = 'piece'}) =>
    ProjectQuote.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': title,
      'status': status,
      'mode': mode,
      'created_at': '2026-10-01T10:00:00Z',
      'updated_at': '2026-10-01T10:00:00Z',
    });

Future<void> _setScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _choose(WidgetTester tester, String label, String value) async {
  final dropdown = find.byWidgetPredicate((widget) =>
      widget is ModuleFilterDropdown<String> && widget.label == label);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Project shortcut selects the clicked project before opening its module',
      (tester) async {
    await _setScreen(tester);
    final projectB = _project.copyWith(id: 'p2', name: 'Chantier B');
    final router = GoRouter(initialLocation: '/projects', routes: [
      GoRoute(path: '/projects', builder: (_, __) => const ProjectsPage()),
      GoRoute(
          path: '/planning',
          builder: (_, __) => Consumer(
              builder: (context, ref, _) => Scaffold(
                  body: Text(
                      'Planning : ${ref.watch(selectedProjectProvider).asData?.value?.name}')))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) async => [_project, projectB]),
        companyProjectsProvider.overrideWith((ref) async => [
              {'id': 'p1', ..._project.toInsertMap()},
              {'id': 'p2', ...projectB.toInsertMap()},
            ]),
      ],
      child: MaterialApp.router(theme: _theme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chantier B');
    await tester.pumpAndSettle();
    final planning = find.widgetWithText(FilledButton, 'Planning');
    await tester.ensureVisible(planning);
    await tester.tap(planning);
    await tester.pumpAndSettle();
    expect(find.text('Planning : Chantier B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Metrage combines search, status, type and level and resets empty results',
      (tester) async {
    await _setScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) async => [_project]),
        spacesProvider.overrideWith((ref) async => [
              _space(1, name: 'Salle RDC', status: RecordStatus.valide),
              _space(2,
                  name: 'Salle étage',
                  level: 'R+1',
                  status: RecordStatus.valide),
              _space(3, name: 'Façade sud', type: SpaceType.facade),
            ]),
      ],
      child: MaterialApp(theme: _theme(), home: const MetragePage()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Salle');
    await tester.pumpAndSettle();
    await _choose(tester, 'Statut', 'Validé');
    await _choose(tester, 'Type', 'Pièce');
    await _choose(tester, 'Niveau', 'R+1');
    expect(find.text('1 espace(s) sur 3'), findsOneWidget);
    expect(find.text('Salle étage • Pièce'), findsOneWidget);
    expect(find.text('Salle RDC • Pièce'), findsNothing);
    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pumpAndSettle();
    expect(
        find.text('Aucun espace ne correspond aux filtres.'), findsOneWidget);
    await tester.ensureVisible(find.text('Réinitialiser'));
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('3 espace(s) sur 3'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Quantitatif scrolls both axes and calculates totals only from filtered spaces',
      (tester) async {
    await _setScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) async => [_project]),
        spacesProvider.overrideWith(
            (ref) async => List.generate(30, (i) => _space(i + 1))),
      ],
      child: MaterialApp(theme: _theme(), home: const QuantitatifPage()),
    ));
    await tester.pumpAndSettle();
    final vertical = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.vertical &&
        widget.controller != null);
    final horizontal = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal &&
        widget.controller != null);
    await tester.drag(vertical, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.widget<SingleChildScrollView>(vertical).controller!.offset,
        greaterThan(0));
    await tester.drag(horizontal, const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<SingleChildScrollView>(horizontal).controller!.offset,
        greaterThan(0));
    await tester.enterText(find.byType(TextField), 'Pièce 29');
    await tester.pumpAndSettle();
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(2));
    expect((table.rows.first.cells[2].child as Text).data, '58.00');
    expect((table.rows.last.cells[2].child as Text).data, '58.00');
    expect(find.text('1 ligne(s) sur 30 · Totaux des lignes affichées'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Devis search and status and mode filters combine and can be reset',
      (tester) async {
    await _setScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) async => [_project]),
        projectQuotesProvider('p1').overrideWith((ref) async => [
              _quote('q1', 'Peinture séjour', status: 'signe'),
              _quote('q2', 'Peinture façade', status: 'signe', mode: 'mixte'),
              _quote('q3', 'Menuiserie'),
            ]),
      ],
      child: MaterialApp(theme: _theme(), home: const DevisListPage()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Peinture');
    await tester.pumpAndSettle();
    await _choose(tester, 'Statut', 'Signé');
    await _choose(tester, 'Mode', 'Mixte');
    expect(find.text('1 devis sur 3'), findsOneWidget);
    expect(find.text('Peinture façade'), findsOneWidget);
    expect(find.text('Peinture séjour'), findsNothing);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('3 devis sur 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
