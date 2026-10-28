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
import 'package:mdi_build/core/models/space_item.dart';
import 'package:mdi_build/features/chat/presentation/providers/chat_providers.dart';
import 'package:mdi_build/features/metrage/data/spaces_repository.dart';
import 'package:mdi_build/features/metrage/presentation/metrage_page.dart';
import 'package:mdi_build/features/metrage/presentation/providers/spaces_providers.dart';
import 'package:mdi_build/features/projects/data/projects_repository.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/shared/presentation/main_shell_page.dart';
import 'package:mdi_build/shared/presentation/project_workspace_toolbar.dart';
import 'package:mdi_build/features/projects/presentation/providers/project_scope_provider.dart';

const _projectA = Project(
  id: 'pA',
  companyId: 'c1',
  name: 'Chantier A',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

final _projectB = _projectA.copyWith(id: 'pB', name: 'Chantier B');

/// Implementing the repository avoids constructing a Supabase client. The
/// actual production providers still drive fetching, refresh and selection.
class _ProjectsRepository implements ProjectsRepository {
  int fetchCount = 0;

  @override
  Future<List<Project>> fetchProjects() async {
    fetchCount++;
    return [_projectA, _projectB];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpacesRepository implements SpacesRepository {
  final fetchedProjectIds = <String>[];

  @override
  Future<List<SpaceItem>> fetchSpaces(String projectId) async {
    fetchedProjectIds.add(projectId);
    return [
      SpaceItem(
        id: 'salon-$projectId',
        companyId: 'c1',
        projectId: projectId,
        type: SpaceType.piece,
        name: 'Salon $projectId',
        levelName: 'RDC',
        length: 4,
        width: 3,
        height: 2.5,
        quantity: 1,
        status: RecordStatus.brouillon,
      ),
      SpaceItem(
        id: 'cuisine-$projectId',
        companyId: 'c1',
        projectId: projectId,
        type: SpaceType.piece,
        name: 'Cuisine $projectId',
        levelName: 'RDC',
        length: 2,
        width: 3,
        height: 2.5,
        quantity: 1,
        status: RecordStatus.brouillon,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ThemeData _theme() {
  final palette = appPalettes[AppPaletteId.blueprintClair]!;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    extensions: [resolvePaletteColors(palette, 0)],
  );
}

GoRouter _router() => GoRouter(initialLocation: '/metrage', routes: [
      ShellRoute(
        builder: (_, __, child) => MainShellPage(child: child),
        routes: [
          GoRoute(path: '/metrage', builder: (_, __) => const MetragePage()),
          GoRoute(
              path: '/planning',
              builder: (_, __) => Consumer(
                    builder: (context, ref, _) => Scaffold(
                      body: Text(
                          'Planning du ${ref.watch(selectedProjectProvider).asData?.value?.name}'),
                    ),
                  )),
        ],
      ),
    ]);

Future<void> _pumpWorkspace(
  WidgetTester tester,
  GoRouter router,
  _ProjectsRepository projects,
  _SpacesRepository spaces,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      // Tests écrits pour la vue « un chantier ».
      projectScopeAllProvider
          .overrideWith(() => ProjectScopeAll(initial: false)),
      projectsRepositoryProvider.overrideWithValue(projects),
      spacesRepositoryProvider.overrideWithValue(spaces),
      chatUnreadTotalProvider.overrideWithValue(0),
    ],
    child: MaterialApp.router(theme: _theme(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Finder _toolbarPicker() => find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.byType(DropdownButton<String>),
    );

Future<void> _selectB(WidgetTester tester) async {
  await tester.tap(_toolbarPicker());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chantier B').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Actualiser refetches real project and space providers without losing search or selected chantier',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = _ProjectsRepository();
    final spaces = _SpacesRepository();
    final router = _router();
    addTearDown(router.dispose);
    await _pumpWorkspace(tester, router, projects, spaces);
    expect(spaces.fetchedProjectIds.last, 'pA');
    await _selectB(tester);
    expect(spaces.fetchedProjectIds.last, 'pB');
    await tester.enterText(find.byType(TextField), 'Salon');
    await tester.pumpAndSettle();
    expect(find.text('Salon pB • Pièce'), findsOneWidget);
    expect(find.text('Cuisine pB • Pièce'), findsNothing);

    final beforeProjects = projects.fetchCount;
    final beforeSpaces = spaces.fetchedProjectIds.length;
    final refresh = find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.widgetWithText(TextButton, 'Actualiser'),
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(projects.fetchCount, greaterThan(beforeProjects));
    expect(spaces.fetchedProjectIds.length, greaterThan(beforeSpaces));
    expect(spaces.fetchedProjectIds.last, 'pB');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Salon');
    expect(tester.widget<DropdownButton<String>>(_toolbarPicker()).value, 'pB');
    expect(find.text('1 espace(s) sur 2'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Planning'));
    await tester.pumpAndSettle();
    expect(find.text('Planning du Chantier B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Workspace toolbar and shell fit 390 portrait and 844 by 390 landscape while preserving selection and search',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = _ProjectsRepository();
    final spaces = _SpacesRepository();
    final router = _router();
    addTearDown(router.dispose);
    await _pumpWorkspace(tester, router, projects, spaces);
    await _selectB(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Salon');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final compactRefresh = find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.byIcon(Icons.refresh),
    );
    await tester.tap(compactRefresh);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<String>>(_toolbarPicker()).value, 'pB');

    await tester.binding.setSurfaceSize(const Size(844, 390));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<DropdownButton<String>>(_toolbarPicker()).value, 'pB');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Salon');
    final toolbar = tester.getRect(find.byType(ProjectWorkspaceToolbar));
    final refresh = tester.getRect(find.descendant(
      of: find.byType(ProjectWorkspaceToolbar),
      matching: find.byIcon(Icons.refresh),
    ));
    expect(toolbar.contains(refresh.center), isTrue);
    expect(spaces.fetchedProjectIds.last, 'pB');
  });
}
