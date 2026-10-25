import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/user_role.dart';
import 'package:mdi_build/core/models/app_user.dart';
import 'package:mdi_build/core/models/chat_message.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_report.dart';
import 'package:mdi_build/features/chat/presentation/chat_page.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis_repository.dart';
import 'package:mdi_build/features/reports/presentation/analysis/report_analysis_providers.dart';
import 'package:mdi_build/features/reports/presentation/providers/reports_providers.dart';
import 'package:mdi_build/features/reports/presentation/reports_page.dart';
import 'package:mdi_build/features/settings/presentation/providers/settings_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/shared/presentation/module_filters.dart';

const _project = Project(
  id: 'filters-project',
  companyId: 'company',
  name: 'Chantier des filtres',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

const _profile = AppUser(
  id: 'me',
  companyId: 'company',
  email: '',
  fullName: 'Utilisateur',
  role: UserRole.directeur,
);

ThemeData _theme() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ThemeData(
    useMaterial3: true,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

ProjectReport _report(
  String id,
  DateTime day, {
  String status = 'generated',
  String type = 'module_auto',
  String module = 'planning',
}) =>
    ProjectReport(
      id: id,
      companyId: 'company',
      projectId: _project.id,
      title: id,
      reportDate: day,
      weather: '',
      progressSummary: 'Suivi coffrage',
      blockers: '',
      decisions: '',
      nextSteps: '',
      authorId: _profile.id,
      isArchived: false,
      createdAt: day,
      updatedAt: day,
      status: status,
      reportType: type,
      sourceModule: module,
    );

ChatMessage _message(String id, String type, String author) => ChatMessage(
      id: id,
      companyId: 'company',
      projectId: _project.id,
      senderId: author,
      senderName: author == 'me' ? 'Utilisateur' : 'Collègue',
      messageType: type,
      textContent: id == 'my-text' ? 'Mon suivi béton' : 'Autre suivi',
      fileName: type == 'file' ? 'Plan béton.pdf' : null,
      fileSize: 0,
      createdAt: DateTime(2026, 10, 21, 9),
      updatedAt: DateTime(2026, 10, 21, 9),
    );

Widget _chatApp() => ProviderScope(
      overrides: [
        selectedProjectProvider.overrideWith((ref) async => _project),
        currentProfileProvider.overrideWith((ref) async => _profile),
        projectsProvider.overrideWith((ref) async => [_project]),
        companyUsersProvider('company').overrideWith((ref) async => const []),
        companyChatMessagesProvider
            .overrideWith((ref) => Stream.value(const [])),
        currentProjectMessagesProvider.overrideWith((ref) => Stream.value([
              _message('other-text', 'text', 'other'),
              _message('my-text', 'text', 'me'),
              _message('my-photo', 'image', 'me'),
              _message('other-document', 'file', 'other'),
              _message('my-audio', 'audio', 'me'),
            ])),
      ],
      child: MaterialApp(theme: _theme(), home: const ChatPage()),
    );

Future<void> _selectFilter(
    WidgetTester tester, String label, String choice) async {
  final filter = find
      .byWidgetPredicate(
        (widget) =>
            widget is ModuleFilterDropdown<String> && widget.label == label,
      )
      .hitTestable();
  await tester.ensureVisible(filter);
  await tester.tap(filter);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  });

  testWidgets('historique rapports : filtres cumulés, dates et remise à zéro',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 2200);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final reports = [
      _report('Rapport récent', now),
      _report('Rapport brouillon', now,
          status: 'draft', type: 'manual', module: 'manual'),
      _report('Rapport ancien', DateTime(now.year - 1, 1, 1)),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        selectedProjectProvider.overrideWith((ref) async => _project),
        currentProfileProvider.overrideWith((ref) async => _profile),
        projectsProvider.overrideWith((ref) async => [_project]),
        activeReportsProvider.overrideWith((ref) async => reports),
        archivedReportsProvider.overrideWith((ref) async => const []),
        activeSuppliersProvider.overrideWith((ref) async => const []),
        archivedSuppliersProvider.overrideWith((ref) async => const []),
        reportPurchasesDataProvider(_project.id).overrideWith(
          (ref) async => const PurchasesData([], {}),
        ),
      ],
      child: MaterialApp(theme: _theme(), home: const ReportsPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();

    expect(find.text('3 sur 3 rapports'), findsOneWidget);
    await _selectFilter(tester, 'Statut du rapport', 'Généré');
    expect(find.text('2 sur 3 rapports'), findsOneWidget);
    await _selectFilter(tester, 'Type de rapport', 'Auto module');
    await _selectFilter(tester, 'Date du rapport', 'Mois en cours');
    expect(find.text('1 sur 3 rapports'), findsOneWidget);
    await _selectFilter(tester, 'Module du rapport', 'Planning');
    final search = find.descendant(
        of: find.byType(ModuleFilterBar), matching: find.byType(TextField));
    await tester.enterText(search, 'coffrage');
    await tester.pumpAndSettle();
    expect(find.text('1 sur 3 rapports'), findsOneWidget);
    expect(find.text('Rapport récent'), findsOneWidget);
    expect(find.text('Rapport ancien'), findsNothing);

    await _selectFilter(tester, 'Statut du rapport', 'Brouillon');
    expect(find.text('0 sur 3 rapports'), findsOneWidget);
    expect(find.text('Aucun rapport pour ce filtre.'), findsOneWidget);
    await tester.ensureVisible(find.text('Réinitialiser'));
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('3 sur 3 rapports'), findsOneWidget);
    expect(find.text('coffrage'), findsNothing);
    await _selectFilter(tester, 'Date du rapport', 'Personnalisée');
    expect(find.text('Dates des rapports'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('3 sur 3 rapports'), findsOneWidget);
    expect(find.text('Toutes les dates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'chat : contenu, auteur et recherche se combinent dans la conversation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_chatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtres des messages'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'Type de contenu', 'Textes');
    expect(find.text('2 sur 5 messages'), findsOneWidget);
    await _selectFilter(tester, 'Auteur', 'Mes messages');
    expect(find.text('1 sur 5 messages'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('other-text')), findsNothing);

    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Rechercher dans la conversation…'),
        'absent');
    await tester.pumpAndSettle();
    expect(find.text('0 sur 5 messages'), findsOneWidget);
    expect(
        find.text(
            'Aucun message ne correspond aux filtres de cette conversation.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Réinitialiser les filtres du chat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('other-document')), findsOneWidget);
    expect(find.textContaining('sur 5 messages'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat filtré : saisie accessible en paysage avec clavier',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_chatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtres des messages'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'Type de contenu', 'Textes');
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(find.byType(TextField).last.hitTestable(), findsOneWidget);
    expect(find.byTooltip('Réinitialiser les filtres du chat').hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
