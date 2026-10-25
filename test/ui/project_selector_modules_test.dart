import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/dashboard_metrics.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/features/achats/presentation/achats_page.dart';
import 'package:mdi_build/features/achats/presentation/providers/purchases_providers.dart';
import 'package:mdi_build/features/chat/presentation/chat_page.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/dashboard/presentation/dashboard_page.dart';
import 'package:mdi_build/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mdi_build/features/devis/presentation/devis_list_page.dart';
import 'package:mdi_build/features/devis/presentation/providers/devis_providers.dart';
import 'package:mdi_build/features/documents/presentation/documents_page.dart';
import 'package:mdi_build/features/documents/presentation/providers/documents_providers.dart';
import 'package:mdi_build/features/metrage/presentation/metrage_page.dart';
import 'package:mdi_build/features/metrage/presentation/providers/spaces_providers.dart';
import 'package:mdi_build/features/planning/presentation/planning_page.dart';
import 'package:mdi_build/features/projects/presentation/projects_page.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/quantitatif/presentation/quantitatif_page.dart';
import 'package:mdi_build/features/reports/analysis/report_analysis_repository.dart';
import 'package:mdi_build/features/reports/presentation/analysis/report_analysis_providers.dart';
import 'package:mdi_build/features/reports/presentation/providers/reports_providers.dart';
import 'package:mdi_build/features/reports/presentation/reports_page.dart';
import 'package:mdi_build/features/settings/presentation/appearance_settings_page.dart';
import 'package:mdi_build/features/settings/presentation/clients_page.dart';
import 'package:mdi_build/features/settings/presentation/company_settings_page.dart';
import 'package:mdi_build/features/settings/presentation/notifications_settings_page.dart';
import 'package:mdi_build/features/settings/presentation/providers/clients_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/tax_rates_providers.dart';
import 'package:mdi_build/features/settings/presentation/settings_page.dart';
import 'package:mdi_build/features/settings/presentation/suppliers_page.dart';
import 'package:mdi_build/features/settings/presentation/tax_rates_page.dart';
import 'package:mdi_build/shared/presentation/project_workspace_toolbar.dart';

const _projectA = Project(
  id: 'project-a',
  companyId: 'company',
  name: 'Chantier A',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

final _projectB = _projectA.copyWith(id: 'project-b', name: 'Chantier B');

ThemeData _theme() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

/// Keep the real selected-project notifier and storage. All remote data is
/// replaced locally so these tests do not initialize or contact Supabase.
ProviderContainer _container() => ProviderContainer(overrides: [
      projectsProvider.overrideWith((ref) async => [_projectA, _projectB]),
      currentProfileProvider.overrideWith((ref) async => null),
      companyProjectsProvider.overrideWith((ref) async => const []),
      dashboardMetricsProvider.overrideWith(
        (ref) async => DashboardMetrics.empty(),
      ),
      spacesProvider.overrideWith((ref) async => const []),
      activePurchasesProvider.overrideWith((ref) async => const []),
      archivedPurchasesProvider.overrideWith((ref) async => const []),
      activeDocumentsProvider.overrideWith((ref) async => const []),
      archivedDocumentsProvider.overrideWith((ref) async => const []),
      activeReportsProvider.overrideWith((ref) async => const []),
      archivedReportsProvider.overrideWith((ref) async => const []),
      activeClientsProvider.overrideWith((ref) async => const []),
      archivedClientsProvider.overrideWith((ref) async => const []),
      activeSuppliersProvider.overrideWith((ref) async => const []),
      archivedSuppliersProvider.overrideWith((ref) async => const []),
      activeTaxRatesProvider.overrideWith((ref) async => const []),
      archivedTaxRatesProvider.overrideWith((ref) async => const []),
      companyChatMessagesProvider.overrideWith((ref) => Stream.value(const [])),
      currentProjectMessagesProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      generalChatMessagesProvider.overrideWith((ref) => Stream.value(const [])),
      for (final project in [_projectA, _projectB]) ...[
        projectQuotesProvider(project.id).overrideWith(
          (ref) async => const [],
        ),
        reportPurchasesDataProvider(project.id).overrideWith(
          (ref) async => const PurchasesData([], {}),
        ),
        reportQuotesDataProvider(project.id).overrideWith(
          (ref) async => const QuotesData([], {}),
        ),
        reportPlanningDataProvider(project.id).overrideWith(
          (ref) async => const PlanningData([], []),
        ),
        reportDocumentsDataProvider(project.id).overrideWith(
          (ref) async => const [],
        ),
        reportSpacesDataProvider(project.id).overrideWith(
          (ref) async => const [],
        ),
      ],
    ]);

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container,
  Widget page,
) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: _theme(), home: page),
  ));
  await tester.pumpAndSettle();
}

Finder _picker() => find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.byType(DropdownButton<String>),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  });

  const modules = <String, Widget>{
    'Tableau de bord': DashboardPage(),
    'Projets': ProjectsPage(),
    'Planning': PlanningPage(),
    'Métré': MetragePage(),
    'Quantitatif': QuantitatifPage(),
    'Devis': DevisListPage(),
    'Achats': AchatsPage(),
    'Documents': DocumentsPage(),
    'Chat': ChatPage(),
    'Rapports': ReportsPage(),
    'Paramètres': SettingsPage(),
    'Entreprise': CompanySettingsPage(),
    'Clients': ClientsPage(),
    'Fournisseurs': SuppliersPage(),
    'Taxes et TVA': TaxRatesPage(),
    'Notifications': NotificationsSettingsPage(),
    'Apparence': AppearanceSettingsPage(),
  };

  for (final module in modules.entries) {
    testWidgets('${module.key} exposes its own visible project selector',
        (tester) async {
      // Appearance's optional font samples are below the fold. Keep this
      // selector test focused on its header without requesting Google Fonts.
      await tester.binding.setSurfaceSize(
        Size(1440, module.value is AppearanceSettingsPage ? 600 : 1600),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = _container();
      addTearDown(container.dispose);

      // No shell is present: every actual module must supply its own toolbar.
      await _show(tester, container, module.value);

      expect(find.byType(ProjectWorkspaceToolbar), findsOneWidget);
      expect(find.text('Sélection du projet'), findsOneWidget);
      expect(_picker().hitTestable(), findsOneWidget);
      expect(
          tester.widget<DropdownButton<String>>(_picker()).value, _projectA.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Planning changes the shared project used by the next module',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _container();
    addTearDown(container.dispose);
    await _show(tester, container, const PlanningPage());
    expect(
        tester.widget<DropdownButton<String>>(_picker()).value, _projectA.id);

    await tester.tap(_picker());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_projectB.name).last);
    await tester.pumpAndSettle();

    expect((await container.read(selectedProjectProvider.future))?.id,
        _projectB.id);
    expect(
        tester.widget<DropdownButton<String>>(_picker()).value, _projectB.id);
    expect(find.textContaining('Chantier B'), findsWidgets);

    await _show(tester, container, const QuantitatifPage());
    expect(find.byType(ProjectWorkspaceToolbar), findsOneWidget);
    expect(find.text('Sélection du projet'), findsOneWidget);
    expect(
        tester.widget<DropdownButton<String>>(_picker()).value, _projectB.id);
    expect(find.text('Projet courant : Chantier B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
