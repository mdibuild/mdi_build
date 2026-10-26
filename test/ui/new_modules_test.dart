import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/checklist_item.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_invoice.dart';
import 'package:mdi_build/core/models/quantity_item.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/checklist/presentation/checklist_page.dart';
import 'package:mdi_build/features/devis/presentation/devis_list_page.dart';
import 'package:mdi_build/features/devis/presentation/providers/devis_providers.dart';
import 'package:mdi_build/features/factures/presentation/invoices_tab.dart';
import 'package:mdi_build/features/factures/presentation/providers/invoices_providers.dart';
import 'package:mdi_build/features/metrage/presentation/metre_quantitatif_page.dart';
import 'package:mdi_build/features/metrage/presentation/providers/spaces_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/clients_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/features/technique/presentation/technique_page.dart';
import 'package:mdi_build/shared/presentation/main_shell_page.dart';
import 'package:mdi_build/shared/presentation/project_workspace_toolbar.dart';

const _project = Project(
  id: 'p1',
  companyId: 'c1',
  name: 'Villa Hydra',
  clientName: 'M. Benali',
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

final _invoice = ProjectInvoice.fromMap({
  'id': 'f1',
  'company_id': 'c1',
  'project_id': 'p1',
  'number': 'FAC-2026-001',
  'title': 'Situation n°1',
  'status': 'partielle',
  'issue_date': '2026-10-01',
  'due_date': '2026-10-31',
  'tax_rate': 19,
  'amount_paid': 500,
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
});

ChecklistItem _todo(String id, String title, {bool done = false}) =>
    ChecklistItem.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': title,
      'is_done': done,
      'created_at': '2026-10-01T08:00:00Z',
    });

ProviderContainer _container() => ProviderContainer(overrides: [
      projectsProvider.overrideWith((ref) async => [_project]),
      currentProfileProvider.overrideWith((ref) async => null),
      spacesProvider.overrideWith((ref) async => const []),
      activeClientsProvider.overrideWith((ref) async => const []),
      archivedClientsProvider.overrideWith((ref) async => const []),
      activeSuppliersProvider.overrideWith((ref) async => const []),
      archivedSuppliersProvider.overrideWith((ref) async => const []),
      chatUnreadTotalProvider.overrideWithValue(0),
      projectQuotesProvider('p1').overrideWith((ref) async => const []),
      projectInvoicesProvider('p1').overrideWith(
        (ref) async => ProjectInvoicesData([
          _invoice
        ], {
          'f1': const [
            InvoiceLineItem(
                label: 'Gros œuvre', quantity: 1, unit: 'fft', unitPrice: 1000),
          ],
        }),
      ),
      quantityItemsProvider('p1').overrideWith((ref) async => const [
            QuantityItem(
              id: 'q1',
              companyId: 'c1',
              projectId: 'p1',
              label: 'Béton de propreté',
              quantity: 12.5,
              unit: 'm³',
              total: 112500,
              sourceFile: 'dqe.xlsx',
            ),
          ]),
      checklistItemsProvider('p1').overrideWith((ref) async => [
            _todo('k1', 'Commander le ciment'),
            _todo('k2', 'Valider le plan', done: true),
          ]),
    ]);

Future<void> _show(WidgetTester tester, Widget page, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = _container();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: _theme(), home: page),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(390, 844), Size(1440, 1000)]) {
    final label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('Technique : béton puis aciers sans débordement ($label)',
        (tester) async {
      await _show(tester, const TechniquePage(), size);
      // 1 m³ de béton 25 MPa + 5 % de pertes = 367,5 kg = 8 sacs de 50 kg.
      await tester.scrollUntilVisible(find.text('8 sacs de 50 kg'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(ConcreteTab),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('8 sacs de 50 kg'), findsOneWidget);
      await tester.tap(find.text('Ronds à béton'));
      await tester.pumpAndSettle();
      expect(find.text('Tableau des aciers HA'), findsOneWidget);
      expect(find.textContaining('= 10,65 kg'), findsWidgets); // 12 m Ø12
      expect(tester.takeException(), isNull);
    });

    testWidgets('Check-list : à faire / faites ($label)', (tester) async {
      await _show(tester, const ChecklistPage(), size);
      expect(find.text('Commander le ciment'), findsOneWidget);
      expect(find.text('Valider le plan'), findsNothing); // filtre « À faire »
      expect(find.text('1 à faire · 1 faite(s)'), findsOneWidget);
      await tester.tap(find.text('Toutes'));
      await tester.pumpAndSettle();
      expect(find.text('Valider le plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Métré & Quantitatif : un seul module, deux onglets ($label)',
        (tester) async {
      await _show(tester, const MetreQuantitatifPage(), size);
      expect(find.text('Métré & Quantitatif'), findsOneWidget);
      expect(find.byType(ProjectWorkspaceToolbar), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Quantitatif'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectWorkspaceToolbar), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Quantités Excel'));
      await tester.pumpAndSettle();
      expect(find.text('Béton de propreté'), findsOneWidget);
      expect(find.textContaining('dqe.xlsx'), findsWidgets);
      // Un projet peut être créé depuis n'importe quel module.
      expect(find.byTooltip('Nouveau projet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Devis & Factures : suivi des encaissements ($label)',
        (tester) async {
      await _show(tester, const DevisListPage(initialTab: 1), size);
      await tester.scrollUntilVisible(find.textContaining('FAC-2026-001'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(InvoicesTab),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.textContaining('FAC-2026-001'), findsOneWidget);
      // TTC 1 190, réglé 500, reste 690.
      expect(find.textContaining('690,00 DA'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Menu regroupé par thèmes avec les nouveaux modules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(initialLocation: '/factures', routes: [
      ShellRoute(
        builder: (_, __, child) => MainShellPage(child: child),
        routes: [
          GoRoute(
              path: '/factures',
              builder: (_, __) => const Scaffold(body: Text('Factures'))),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: _theme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    for (final text in [
      'PILOTAGE',
      'ÉTUDES & CHIFFRAGE',
      'CHANTIER',
      'Check-list',
      'Métré & Quantitatif',
      'Devis & Factures',
      'Technique',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // /factures met en évidence « Devis & Factures ».
    final selected = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected == true);
    expect(selected, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
