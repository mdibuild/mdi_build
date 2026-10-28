import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mdi_build/app/theme/app_palette.dart';
import 'package:mdi_build/app/theme/app_palette_colors.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/checklist_item.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/purchase_workflow.dart';
import 'package:mdi_build/features/checklist/data/checklist_repository.dart';
import 'package:mdi_build/features/checklist/presentation/checklist_page.dart';
import 'package:mdi_build/features/projects/presentation/providers/current_profile_provider.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/selected_project_provider.dart';
import 'package:mdi_build/features/settings/presentation/providers/clients_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/project_scope_provider.dart';

const _project = Project(
  id: 'p1',
  companyId: 'c1',
  name: 'Villa Hydra',
  clientName: '',
  location: '',
  description: '',
  budgetInitial: 0,
  progress: 0,
  status: RecordStatus.enCours,
);

class _Repo implements ChecklistRepository {
  final done = <String, bool>{};
  final updated = <ChecklistItem>[];

  @override
  Future<void> setDone(String id, bool value) async => done[id] = value;

  @override
  Future<void> updateItem(ChecklistItem item) async => updated.add(item);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _task = ChecklistItem.fromMap({
  'id': 'k1',
  'company_id': 'c1',
  'project_id': 'p1',
  'title': 'Commander le ciment',
  'is_done': false,
  'due_at': '2026-11-02T08:30:00Z',
  'reminder_minutes': 60,
  'created_at': '2026-10-01T08:00:00Z',
});

void main() {
  group('Achats : avancer ou revenir en arrière', () {
    test('étape précédente et champs effacés au retour', () {
      expect(PurchaseWorkflow.previousStep('livre'), 'commande');
      expect(PurchaseWorkflow.previousStep('brouillon'), isNull);
      expect(PurchaseWorkflow.isBackward('livre', 'dg_valide'), isTrue);
      expect(PurchaseWorkflow.isBackward('dg_valide', 'livre'), isFalse);
      final back = PurchaseWorkflow.fieldsClearedBy('dg_valide');
      expect(back, containsAll(['ordered_at', 'delivered_at']));
      expect(back, isNot(contains('approved_at')));
      expect(PurchaseWorkflow.fieldsClearedBy('brouillon'),
          containsAll(['approved_at', 'ordered_at', 'delivered_at']));
      expect(PurchaseWorkflow.fieldsClearedBy('annule'), isEmpty);
    });
  });

  test('tâche : modification et effacement de l’échéance', () {
    final cleared = _task.copyWith(
      title: 'Commander 20 sacs',
      clearDue: true,
      clearReminder: true,
      clearAssignee: true,
    );
    final map = cleared.toUpdateMap(clearSchedule: true);
    expect(map['title'], 'Commander 20 sacs');
    expect(map.containsKey('due_at'), isTrue);
    expect(map['due_at'], isNull);
    expect(map['due_date'], isNull);
    expect(map['assigned_to'], isNull);
    final moved = _task.copyWith(dueAt: DateTime(2026, 11, 5, 14));
    expect(moved.dueDate, DateTime(2026, 11, 5));
    expect(moved.reminderMinutes, 60);
  });

  testWidgets('Check-list : appui court = faite, appui long = modifier',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      // Tests écrits pour la vue « un chantier ».
      projectScopeAllProvider
          .overrideWith(() => ProjectScopeAll(initial: false)),
      projectsProvider.overrideWith((ref) async => [_project]),
      selectedProjectProvider.overrideWith((ref) async => _project),
      currentProfileProvider.overrideWith((ref) async => null),
      activeClientsProvider.overrideWith((ref) async => const []),
      activeSuppliersProvider.overrideWith((ref) async => const []),
      checklistRepositoryProvider.overrideWithValue(repo),
      checklistItemsProvider('p1').overrideWith((ref) async => [_task]),
    ]);
    addTearDown(container.dispose);
    final palette = appPalettes[AppPaletteId.blueprintClair]!;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [resolvePaletteColors(palette, 0)]),
        home: const ChecklistPage(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commander le ciment'));
    await tester.pumpAndSettle();
    expect(repo.done['k1'], isTrue);

    await tester.longPress(find.text('Commander le ciment'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la tâche'), findsOneWidget);
    expect(find.textContaining('Pour le 02/11/2026'), findsOneWidget);
    await tester.tap(find.text('Retirer l’échéance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.dueAt, isNull);
    expect(find.text('Modifier la tâche'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
