import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/models/project.dart';
import 'package:mdi_build/core/models/project_document.dart';
import 'package:mdi_build/features/documents/data/documents_repository.dart';
import 'package:mdi_build/features/documents/presentation/document_form_dialog.dart';
import 'package:mdi_build/features/documents/presentation/providers/documents_providers.dart';
import 'package:mdi_build/features/projects/presentation/providers/projects_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/clients_providers.dart';
import 'package:mdi_build/features/settings/presentation/providers/suppliers_providers.dart';

Project _project(String id, String name) => Project(
      id: id,
      companyId: 'c1',
      name: name,
      clientName: '',
      location: '',
      description: '',
      budgetInitial: 0,
      progress: 0,
      status: RecordStatus.enCours,
    );

class _Repo implements DocumentsRepository {
  final updated = <ProjectDocument>[];

  @override
  Future<ProjectDocument> updateDocument(ProjectDocument document) async {
    updated.add(document);
    return document;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _document = ProjectDocument(
  id: 'd1',
  companyId: 'c1',
  projectId: 'p1',
  bucketId: 'project-documents',
  filePath: 'projects/p1/general/plan.pdf',
  fileName: 'plan.pdf',
  mimeType: 'application/pdf',
  fileSize: 2048,
  title: 'Plan RDC',
  description: 'Version A',
  category: 'plan',
  isArchived: false,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  testWidgets('Documents : modifier titre et chantier, sans écran noir',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(repo),
        projectsProvider.overrideWith((ref) async => [
              _project('p1', 'Villa Hydra'),
              _project('p2', 'Immeuble Oran'),
            ]),
        activeDocumentsProvider.overrideWith((ref) async => const []),
        archivedDocumentsProvider.overrideWith((ref) async => const []),
        activeClientsProvider.overrideWith((ref) async => const []),
        activeSuppliersProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => DocumentFormDialog(document: _document),
                ),
                child: const Text('Page Documents'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Page Documents'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le document'), findsOneWidget);
    expect(find.textContaining('Fichier actuel : plan.pdf'), findsOneWidget);
    expect(find.text('Plan RDC'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Plan RDC'), 'Plan RDC indice B');
    await tester.tap(find.text('Villa Hydra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Immeuble Oran').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = repo.updated.single;
    expect(saved.title, 'Plan RDC indice B');
    expect(saved.projectId, 'p2');
    expect(saved.filePath, _document.filePath); // fichier gardé
    expect(saved.toUpdateMap()['project_id'], 'p2');
    // La fenêtre est fermée, la page dessous est toujours là.
    expect(find.text('Modifier le document'), findsNothing);
    expect(find.text('Page Documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
