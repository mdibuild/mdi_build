import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/models/project_task.dart';
import 'package:mdi_build/core/models/project_task_dependency.dart';
import 'package:mdi_build/features/planning/presentation/gantt_view.dart';

const _ts = '2026-01-01T00:00:00Z';

ProjectTask _t(String id, String start, String end) => ProjectTask.fromMap({
      'id': id, 'company_id': 'c1', 'project_id': 'p1', 'task_type': 'task',
      'title': 'Tâche $id', 'description': '', 'lot': '', 'status': 'en_cours',
      'priority': 'normale', 'progress': 40, 'planned_start_date': start,
      'planned_end_date': end, 'planned_duration_days': 0, 'sort_order': 0,
      'is_archived': false, 'created_at': _ts, 'updated_at': _ts,
    });

Widget _gantt() => MaterialApp(
      theme: ThemeData(extensions: [
        resolvePaletteColors(appPalettes[AppPaletteId.blueprintClair]!, 0),
      ]),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GanttView(
            tasks: [
              _t('courte', '2026-03-10', '2026-03-12'), // 3 jours
              _t('longue', '2026-01-15', '2027-02-20'), // > 1 an
            ],
            dependencies: [
              ProjectTaskDependency.fromMap({
                'id': 'd', 'company_id': 'c1', 'project_id': 'p1',
                'predecessor_task_id': 'courte', 'successor_task_id': 'longue',
                'dependency_type': 'start_to_start', 'created_at': _ts, 'updated_at': _ts,
              }),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('les 7 échelles du Gantt s’affichent sans erreur', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(900, 700) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_gantt());
    await tester.pumpAndSettle();

    for (final scale in GanttScale.values) {
      await tester.ensureVisible(find.text(scale.label));
      await tester.tap(find.text(scale.label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: scale.label);
    }
    // Libellés en français des grandes échelles.
    await tester.tap(find.text('Trimestre'));
    await tester.pumpAndSettle();
    expect(find.textContaining('T1 2026'), findsOneWidget);
    await tester.tap(find.text('Semestre'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1er semestre'), findsWidgets);
    await tester.tap(find.text('Année'));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2027'), findsOneWidget);
  });
}
