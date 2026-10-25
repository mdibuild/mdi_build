import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_document.dart';
import 'package:mdi_build/core/models/purchase.dart';
import 'package:mdi_build/core/models/purchase_item.dart';
import 'package:mdi_build/features/achats/data/purchases_repository.dart';
import 'package:mdi_build/features/achats/presentation/achats_page.dart';
import 'package:mdi_build/features/achats/presentation/providers/purchases_providers.dart';
import 'package:mdi_build/features/documents/presentation/documents_page.dart';
import 'package:mdi_build/features/documents/data/documents_repository.dart';
import 'package:mdi_build/features/documents/presentation/providers/documents_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';

const _alpha = Project(
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
const _beta = Project(
  id: 'beta',
  companyId: 'company',
  name: 'Projet Beta',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

Widget _app(Widget page) {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      extensions: [resolvePaletteColors(palette, 0)],
    ),
    home: page,
  );
}

class _PurchasesRepository implements PurchasesRepository {
  @override
  Future<List<PurchaseItem>> fetchPurchaseItems(String purchaseId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DocumentsRepository implements DocumentsRepository {
  @override
  Future<String> createSignedUrl({
    required String bucketId,
    required String filePath,
    int expiresInSeconds = 3600,
  }) async =>
      '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Purchase _purchase(String id, String projectId) => Purchase.fromMap({
      'id': id,
      'company_id': 'company',
      'project_id': projectId,
      'title': 'Commande $id',
      'lot': 'Gros œuvre',
      'status': 'brouillon',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

ProjectDocument _document(
  String id, {
  String mimeType = 'application/pdf',
  String category = 'plan',
  String? reportId,
  int ageDays = 0,
}) =>
    ProjectDocument.fromMap({
      'id': id,
      'company_id': 'company',
      'project_id': 'alpha',
      'title': 'Document $id',
      'file_name': '$id.pdf',
      'mime_type': mimeType,
      'category': category,
      'report_id': reportId,
      'created_at':
          DateTime.now().subtract(Duration(days: ageDays)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

Future<void> _choose(WidgetTester tester, String label, String choice) async {
  final field = find.byWidgetPredicate((widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('achats follows current project and keeps explicit global scope',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = _alpha;
    final container = ProviderContainer(overrides: [
      projectsProvider.overrideWith((ref) async => [_alpha, _beta]),
      selectedProjectProvider.overrideWith((ref) async => selected),
      activePurchasesProvider.overrideWith((ref) async => [
            _purchase('Alpha', 'alpha'),
            _purchase('Beta', 'beta'),
          ]),
      archivedPurchasesProvider.overrideWith((ref) async => []),
      activeSuppliersProvider.overrideWith((ref) async => []),
      purchasesRepositoryProvider.overrideWithValue(_PurchasesRepository()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _app(const AchatsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Commande Alpha'), findsOneWidget);
    expect(find.text('Commande Beta'), findsNothing);

    selected = _beta;
    container.invalidate(selectedProjectProvider);
    await tester.pumpAndSettle();
    expect(find.text('Commande Alpha'), findsNothing);
    expect(find.text('Commande Beta'), findsOneWidget);

    await _choose(tester, 'Projet', 'Tous les projets');
    expect(find.text('Commande Alpha'), findsOneWidget);
    expect(find.text('Commande Beta'), findsOneWidget);

    selected = _alpha;
    container.invalidate(selectedProjectProvider);
    await tester.pumpAndSettle();
    expect(find.text('Commande Alpha'), findsOneWidget);
    expect(find.text('Commande Beta'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'introuvable');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun achat ne correspond'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('Commande Alpha'), findsOneWidget);
    expect(find.text('Commande Beta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'documents combines file type, report relation and date then resets',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final documents = [
      _document('Plan récent', reportId: 'report'),
      _document('Photo', mimeType: 'image/png', category: 'photo'),
      _document('Plan ancien', ageDays: 60),
    ];
    final container = ProviderContainer(overrides: [
      selectedProjectProvider.overrideWith((ref) async => _alpha),
      activeDocumentsProvider.overrideWith((ref) async => documents),
      archivedDocumentsProvider.overrideWith((ref) async => []),
      documentsRepositoryProvider.overrideWithValue(_DocumentsRepository()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _app(const DocumentsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Document Photo'), findsOneWidget);
    await _choose(tester, 'Type de fichier', 'PDF');
    expect(find.text('Document Photo'), findsNothing);
    expect(find.text('Document Plan ancien'), findsOneWidget);
    await _choose(tester, 'Ajout', '7 derniers jours');
    expect(find.text('Document Plan ancien'), findsNothing);
    expect(find.text('Document Plan récent'), findsOneWidget);
    await _choose(tester, 'Liaison', 'Liés à un rapport');
    expect(find.text('Document Plan récent'), findsOneWidget);
    expect(find.text('Document Plan ancien'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'aucun résultat');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun document ne correspond'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('Document Photo'), findsOneWidget);
    expect(find.text('Document Plan récent'), findsOneWidget);
    expect(find.text('3 document(s) sur 3 · en cours et archives'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Plan ancien');
    await tester.pumpAndSettle();
    expect(find.text('1 document(s) sur 3 · en cours et archives'),
        findsOneWidget);
    expect(find.text('Document Plan ancien'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operation filters remain reachable on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      projectsProvider.overrideWith((ref) async => [_alpha, _beta]),
      selectedProjectProvider.overrideWith((ref) async => _alpha),
      activePurchasesProvider.overrideWith((ref) async => []),
      archivedPurchasesProvider.overrideWith((ref) async => []),
      activeSuppliersProvider.overrideWith((ref) async => []),
      activeDocumentsProvider.overrideWith((ref) async => []),
      archivedDocumentsProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _app(const AchatsPage()),
    ));
    await tester.pumpAndSettle();
    await _choose(tester, 'Création', '7 derniers jours');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _app(const DocumentsPage()),
    ));
    await tester.pumpAndSettle();
    await _choose(tester, 'Type de fichier', 'PDF');
    expect(tester.takeException(), isNull);
  });
}
