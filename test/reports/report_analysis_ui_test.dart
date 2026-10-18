import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/user_role.dart';
import 'package:mdi_build/core/models/app_user.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_task.dart';
import 'package:mdi_build/core/models/purchase.dart';
import 'package:mdi_build/core/models/purchase_item.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis_export.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis_repository.dart';
import 'package:mdi_build/features/reports/presentation/analysis/report_analysis_providers.dart';
import 'package:mdi_build/features/reports/presentation/analysis/report_analysis_tab.dart';
import 'package:mdi_build/features/settings/presentation/providers/settings_providers.dart';

const _project = Project(
  id: 'p1',
  companyId: 'c1',
  name: 'Villa Hydra',
  clientName: 'M. Benali',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

String _iso(DateTime d) => d.toUtc().toIso8601String();

Purchase _purchase(String id, DateTime created, {String status = 'commande', String lot = 'Gros œuvre'}) =>
    Purchase.fromMap({
      'id': id,
      'company_id': 'c1',
      'project_id': 'p1',
      'title': 'Achat $id',
      'lot': lot,
      'notes': '',
      'status': status,
      'created_at': _iso(created),
      'updated_at': _iso(created),
    });

PurchaseItem _item(String id, String purchaseId, num qty, num price) => PurchaseItem.fromMap({
      'id': id,
      'purchase_id': purchaseId,
      'article': 'Article $id',
      'description': 'Désignation $id',
      'quantity': qty,
      'unit': 'u',
      'unit_price': price,
      'notes': '',
      'sort_order': 0,
      'created_at': _iso(DateTime.now()),
      'updated_at': _iso(DateTime.now()),
    });

ProjectTask _task(String id, DateTime? start, DateTime? end, {String status = 'en_cours'}) {
  String? d(DateTime? v) => v == null
      ? null
      : '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  return ProjectTask.fromMap({
    'id': id,
    'company_id': 'c1',
    'project_id': 'p1',
    'task_type': 'task',
    'title': 'Tâche $id',
    'description': '',
    'lot': '',
    'status': status,
    'priority': 'normale',
    'progress': 30,
    'planned_start_date': d(start),
    'planned_end_date': d(end),
    'planned_duration_days': 0,
    'sort_order': 0,
    'is_archived': false,
    'created_at': _iso(DateTime.now()),
    'updated_at': _iso(DateTime.now()),
  });
}

final _today = DateTime.now();
final _thisMonth = DateTime(_today.year, _today.month, 2, 12);
final _longAgo = DateTime(_today.year - 1, 1, 15, 12);

final _purchases = [
  _purchase('a1', _thisMonth),
  _purchase('a2', _thisMonth, status: 'livre', lot: 'Électricité'), // sans ligne
  _purchase('a3', _thisMonth, status: 'brouillon'),
  _purchase('a4', _longAgo), // hors « ce mois »
];
final _items = {
  'a1': [_item('i1', 'a1', 2, 1500), _item('i2', 'a1', 1, 0)],
  'a3': [_item('i3', 'a3', 10, 250)],
  'a4': [_item('i4', 'a4', 1, 99999)],
};

Widget _app() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ProviderScope(
    overrides: [
      selectedProjectProvider.overrideWith((ref) async => _project),
      projectsProvider.overrideWith((ref) async => const [_project]),
      currentProfileProvider.overrideWith((ref) async => const AppUser(
          id: 'u1', companyId: 'c1', email: '', fullName: 'Med', role: UserRole.directeur)),
      companyUsersProvider('c1').overrideWith((ref) async => const []),
      reportPurchasesDataProvider('p1').overrideWith((ref) async => PurchasesData(_purchases, _items)),
      reportPlanningDataProvider('p1').overrideWith((ref) async => PlanningData([
            _task('avant-periode', _today.subtract(const Duration(days: 60)), _today.add(const Duration(days: 3))),
            _task('pendant', _today, _today.add(const Duration(days: 5)), status: 'a_faire'),
            _task('sans-date', null, null),
          ], const [])),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [resolvePaletteColors(palette, 0)]),
      home: const Scaffold(body: ReportAnalysisTab()),
    ),
  );
}

void _screen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
}

/// Fait défiler la page vers le bas jusqu'à ce que [finder] soit visible
/// (tolère qu'un même texte figure à plusieurs endroits).
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  // Défilement programmatique de la page (et non par geste) : un geste
  // posé sur le Gantt ferait défiler le Gantt lui-même, pas la page.
  final page = tester.state<ScrollableState>(find.byType(Scrollable).first);
  for (var i = 0; i < 80 && finder.hitTestable().evaluate().isEmpty; i++) {
    final pos = page.position;
    if (pos.pixels >= pos.maxScrollExtent) {
      break;
    }
    pos.jumpTo((pos.pixels + 200).clamp(0, pos.maxScrollExtent));
    await tester.pump();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in {
    'portrait': const Size(390, 844),
    'paysage': const Size(844, 390),
    'tablette': const Size(1180, 820),
  }.entries) {
    testWidgets('achats ${entry.key} : exhaustif, sans débordement, totaux cohérents', (tester) async {
      _screen(tester, entry.value);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Les 3 achats du mois sont listés, y compris celui sans montant.
      for (final id in ['a1', 'a2', 'a3']) {
        await _scrollTo(tester, find.text('Achat $id'));
        expect(find.text('Achat $id'), findsOneWidget);
      }
      expect(find.text('Achat a4'), findsNothing); // hors période
      await _scrollTo(tester, find.text('Non renseigné'));
      expect(find.text('Non renseigné'), findsOneWidget); // a2 : pas « 0 »
      // Total = 3000 + 0 + 2500, a2 exclu et signalé.
      await _scrollTo(tester, find.text('Total général connu'));
      expect(find.text(formatAmount(5500)), findsWidgets);
      expect(find.text('Achats sans montant (exclus du total)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('« Depuis le début » inclut l’achat ancien', (tester) async {
    _screen(tester, const Size(390, 844));
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Sur téléphone, les périodes défilent horizontalement : on fait
    // apparaître le choix comme un utilisateur le ferait.
    await tester.ensureVisible(find.text('Depuis le début'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Depuis le début'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Achat a4'));
    expect(find.text('Achat a4'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('planning ${size.width > size.height ? 'paysage' : 'portrait'} : Gantt, chevauchement, tâches sans date', (tester) async {
      _screen(tester, size);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Planning'));
      await tester.tap(find.text('Planning'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text('Diagramme de Gantt'));
      expect(find.text('Diagramme de Gantt'), findsWidgets);
      // La tâche commencée avant la période est incluse (chevauchement).
      await _scrollTo(tester, find.text('Tâche avant-periode')); // Gantt + liste
      expect(find.text('Tâche avant-periode'), findsWidgets);
      await _scrollTo(tester, find.textContaining('Tâches sans dates prévues'));
      expect(find.text('Tâche sans-date'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  group('Exports', () {
    AnalysisReport purchasesReport(List<Purchase> purchases, Map<String, List<PurchaseItem>> items) =>
        AnalysisReport(
          module: ReportModule.achats,
          projectName: 'Villa Hydra',
          period: ReportPeriod.preset(ReportPeriodPreset.allTime),
          activeFilters: const [],
          generatedAt: DateTime(2026, 10, 18),
          purchases: buildPurchasesReport(
            purchases: purchases,
            itemsByPurchase: items,
            period: ReportPeriod.preset(ReportPeriodPreset.allTime),
          ),
        );

    test('Excel : toutes les lignes et même total que le rapport', () {
      final report = purchasesReport(_purchases, _items);
      final excel = Excel.decodeBytes(ReportAnalysisExport().buildExcel(report));
      final rows = excel['Détail'].rows.skip(1).toList();
      // 1 ligne par article + 1 ligne pour l'achat sans article.
      expect(rows.length, report.purchases!.lineCount + report.purchases!.withoutAmount);
      double sum = 0;
      for (final r in rows) {
        final v = r[12]?.value;
        if (v is DoubleCellValue) sum += v.value;
        if (v is IntCellValue) sum += v.value;
      }
      expect(sum, report.purchases!.knownTotal);
      final purchaseIds = rows.map((r) => (r[1]?.value as TextCellValue).value.text).toSet();
      expect(purchaseIds.length, report.purchases!.count);
    });

    test('PDF : rapport long sur plusieurs pages, sans troncature', () async {
      const fontPath = r'C:\src\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf';
      if (!File(fontPath).existsSync()) {
        markTestSkipped('police de test indisponible');
        return;
      }
      final font = pw.Font.ttf(File(fontPath).readAsBytesSync().buffer.asByteData());
      final many = [
        for (var i = 0; i < 300; i++) _purchase('p$i', _thisMonth),
      ];
      final items = {
        for (var i = 0; i < 300; i++) 'p$i': [_item('x$i', 'p$i', 1, 100)],
      };
      final bytes = await ReportAnalysisExport()
          .buildPdf(purchasesReport(many, items), regular: font, bold: font);
      final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;
      expect(pages, greaterThan(5));
    });
  });
}
