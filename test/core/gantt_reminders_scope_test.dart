import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/checklist_item.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/features/checklist/services/checklist_reminders.dart';
import 'package:mdi_build/features/planning/presentation/gantt_view.dart';
import 'package:mdi_build/features/planning/services/gantt_pdf.dart';
import 'package:mdi_build/features/projects/presentation/providers/project_scope_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/shared/presentation/project_workspace_toolbar.dart';

const _a = Project(
  id: 'pa',
  companyId: 'c1',
  name: 'Chantier A',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);
final _b = _a.copyWith(id: 'pb', name: 'Chantier B');

GanttPdfRow _row(int startDay, int days) => GanttPdfRow(
      title: 'T$startDay',
      start: DateTime(2026, 1, 1).add(Duration(days: startDay)),
      end: DateTime(2026, 1, 1).add(Duration(days: startDay + days)),
    );

ChecklistItem _item({
  required String id,
  DateTime? dueAt,
  String? assignedTo,
  String createdBy = 'u1',
  int? reminder = 0,
  bool done = false,
}) =>
    ChecklistItem(
      id: id,
      companyId: 'c1',
      title: 'Tâche $id',
      isDone: done,
      createdAt: DateTime(2026, 10, 1),
      dueAt: dueAt,
      assignedTo: assignedTo,
      createdBy: createdBy,
      reminderMinutes: reminder,
    );

void main() {
  group('Gantt imprimé', () {
    test('colonnes par échelle', () {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 3, 31);
      expect(ganttColumns(from, to, GanttScale.day).length, 90);
      final weeks = ganttColumns(from, to, GanttScale.week);
      expect(weeks.first.start, DateTime(2025, 12, 29)); // lundi
      expect(weeks.first.label, 'S1');
      expect(weeks.every((c) => c.days == 7), isTrue);
      final months = ganttColumns(from, to, GanttScale.month);
      expect(months.map((c) => c.label), ['janv 26', 'févr 26', 'mars 26']);
      expect(
          ganttColumns(from, to, GanttScale.quarter).single.label, 'T1 2026');
      expect(
          ganttColumns(DateTime(2026, 5, 1), DateTime(2026, 8, 1),
                  GanttScale.semester)
              .map((c) => c.label),
          ['S1 2026', 'S2 2026']);
    });

    test('planches : découpage en largeur et en hauteur', () {
      // 60 tâches étalées sur un an.
      final rows = [for (var i = 0; i < 60; i++) _row(i * 6, 10)];
      final days = GanttPdfLayout(rows: rows, scale: GanttScale.day);
      expect(days.horizontalSheets, greaterThan(1));
      expect(days.verticalSheets, (60 / days.rowsPerPage).ceil());
      expect(days.sheets, days.horizontalSheets * days.verticalSheets);
      final year = GanttPdfLayout(rows: rows, scale: GanttScale.year);
      expect(year.horizontalSheets, 1);
      // L'échelle conseillée tient sur 2 planches au plus en largeur.
      final auto = autoGanttScale(rows);
      expect(GanttPdfLayout(rows: rows, scale: auto).horizontalSheets,
          lessThanOrEqualTo(2));
    });
  });

  group('Rappels de la check-list', () {
    final now = DateTime(2026, 10, 26, 10);
    test('échéance avec heure, retard et moment du rappel', () {
      final item =
          _item(id: 'a', dueAt: DateTime(2026, 10, 26, 14, 30), reminder: 60);
      expect(item.reminderAt, DateTime(2026, 10, 26, 13, 30));
      expect(item.isOverdue(today: now), isFalse);
      expect(item.isOverdue(today: DateTime(2026, 10, 26, 15)), isTrue);
      expect(_item(id: 'b', dueAt: now, reminder: null).reminderAt, isNull);
      final map = item.toInsertMap();
      expect(map['due_at'], isNotNull);
      expect(map['reminder_minutes'], 60);
      // Sans échéance : les colonnes v2.3 ne sont pas envoyées.
      expect(_item(id: 'c').toInsertMap().containsKey('due_at'), isFalse);
    });

    test(
        'rappels de l’utilisateur : destinataire et émetteur',
        () {
      final later = DateTime(2026, 10, 27, 9);
      final items = [
        _item(id: 'pour-moi', dueAt: later, assignedTo: 'u1', createdBy: 'u2'),
        _item(id: 'pour-autre', dueAt: later, assignedTo: 'u2'),
        _item(id: 'cree-sans-dest', dueAt: later),
        _item(id: 'faite', dueAt: later, assignedTo: 'u1', done: true),
        _item(id: 'passee', dueAt: DateTime(2026, 10, 25), assignedTo: 'u1'),
        _item(id: 'sans-echeance', assignedTo: 'u1'),
      ];
      expect(remindersFor(items, 'u1', now: now).map((i) => i.id),
          ['pour-moi', 'pour-autre', 'cree-sans-dest']);
      expect(reminderNotificationId('x'), reminderNotificationId('x'));
      expect(reminderNotificationId('x') & 0x40000000, isNonZero);
    });
  });

  group('Tous les projets', () {
    test('par défaut, les modules affichent tous les projets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(projectScopeAllProvider), isTrue);
    });

    test('portée : chantier sélectionné ou tous', () async {
      final container = ProviderContainer(overrides: [
        // Tests écrits pour la vue « un chantier ».
        projectScopeAllProvider
            .overrideWith(() => ProjectScopeAll(initial: false)),
        projectsProvider.overrideWith((ref) async => [_a, _b]),
        selectedProjectProvider.overrideWith((ref) async => _a),
      ]);
      addTearDown(container.dispose);
      expect(
          (await container.read(scopedProjectsProvider.future))
              .map((p) => p.id),
          ['pa']);
      container.read(projectScopeAllProvider.notifier).set(true);
      expect(
          (await container.read(scopedProjectsProvider.future))
              .map((p) => p.id),
          ['pa', 'pb']);
    });

    testWidgets('« Tous les projets » proposé dans la barre de chaque module',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        // Tests écrits pour la vue « un chantier ».
        projectScopeAllProvider
            .overrideWith(() => ProjectScopeAll(initial: false)),
        projectsProvider.overrideWith((ref) async => [_a, _b]),
        selectedProjectProvider.overrideWith((ref) async => _a),
      ]);
      addTearDown(container.dispose);
      final palette = appPalettes[AppPaletteId.blueprintClair]!;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [resolvePaletteColors(palette, 0)]),
          home: const Scaffold(body: ProjectWorkspaceToolbar()),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Tous les projets'), findsWidgets);
      await tester.tap(find.text('Tous les projets').last);
      await tester.pumpAndSettle();
      expect(container.read(projectScopeAllProvider), isTrue);
      expect(
          tester
              .widget<DropdownButton<String>>(
                  find.byType(DropdownButton<String>))
              .value,
          '__all__');
      expect(tester.takeException(), isNull);
    });
  });
}
