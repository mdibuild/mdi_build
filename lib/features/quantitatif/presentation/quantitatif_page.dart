import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/quantity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../achats/presentation/providers/purchases_providers.dart';
import '../../achats/presentation/widgets/purchase_form.dart';
import '../../metrage/presentation/providers/spaces_providers.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';

class QuantitatifPage extends ConsumerWidget {
  const QuantitatifPage({super.key});

  Future<void> _openGeneratePurchaseDialog(
    BuildContext context,
    WidgetRef ref, {
    required dynamic line,
    required String projectId,
    required String projectName,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    final authUser = SupabaseService.client.auth.currentUser;

    if (profile == null || authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
      }
      return;
    }

    final purchaseItems = <PurchaseItem>[
      if (line.floorArea > 0)
        PurchaseItem(
          id: '',
          purchaseId: '',
          article: 'Quantité sol - ${line.spaceName}',
          description: 'Surface sol à approvisionner depuis le quantitatif',
          quantity: (line.floorArea as num).toDouble(),
          unit: 'mÃƒâDAš²',
          unitPrice: 0,
          notes: '',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      if (line.ceilingArea > 0)
        PurchaseItem(
          id: '',
          purchaseId: '',
          article: 'Quantité plafond - ${line.spaceName}',
          description: 'Surface plafond à approvisionner depuis le quantitatif',
          quantity: (line.ceilingArea as num).toDouble(),
          unit: 'mÃƒâDAš²',
          unitPrice: 0,
          notes: '',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      if (line.netWallArea > 0)
        PurchaseItem(
          id: '',
          purchaseId: '',
          article: 'Quantité murs nets - ${line.spaceName}',
          description:
              'Surface murs nets à approvisionner depuis le quantitatif',
          quantity: (line.netWallArea as num).toDouble(),
          unit: 'mÃƒâDAš²',
          unitPrice: 0,
          notes: '',
          sortOrder: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    final draftPurchase = Purchase(
      id: '',
      companyId: profile.companyId,
      projectId: projectId,
      title: 'Achat généré - ${line.spaceName}',
      lot: line.spaceType.toString(),
      notes: 'Généré depuis le quantitatif de $projectName',
      status: 'brouillon',
      requestedBy: authUser.id,
      approvedBy: null,
      orderedBy: null,
      deliveredBy: null,
      cancelledBy: null,
      archivedBy: null,
      approvedAt: null,
      orderedAt: null,
      deliveredAt: null,
      cancelledAt: null,
      archivedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Générer achat depuis le quantitatif'),
          content: SizedBox(
            width: 760,
            child: PurchaseForm(
              projectOptions: [
                DropdownMenuItem<String>(
                  value: projectId,
                  child: Text(projectName),
                ),
              ],
              initialPurchase: draftPurchase,
              initialItems: purchaseItems,
              onSubmit: (value) async {
                final purchase = Purchase(
                  id: '',
                  companyId: profile.companyId,
                  projectId: value.projectId,
                  title: value.title,
                  lot: value.lot,
                  notes: value.notes,
                  status: 'brouillon',
                  requestedBy: authUser.id,
                  approvedBy: null,
                  orderedBy: null,
                  deliveredBy: null,
                  cancelledBy: null,
                  archivedBy: null,
                  approvedAt: null,
                  orderedAt: null,
                  deliveredAt: null,
                  cancelledAt: null,
                  archivedAt: null,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref.read(purchasesRepositoryProvider).createPurchase(
                      purchase,
                      value.items,
                    );

                ref.invalidate(activePurchasesProvider);
                ref.invalidate(archivedPurchasesProvider);

                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Achat généré depuis le quantitatif.')),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProjectAsync = ref.watch(selectedProjectProvider);
    final spacesAsync = ref.watch(spacesProvider);
    final quantityService = QuantityService();

    return Scaffold(
      appBar: AppBar(title: const Text('Quantitatif')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            selectedProjectAsync.when(
              data: (project) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  project == null
                      ? 'Aucun projet courant.'
                      : 'Projet courant : ${project.name}',
                ),
              ),
              loading: () => const Align(
                alignment: Alignment.centerLeft,
                child: Text('Chargement projet courant...'),
              ),
              error: (_, __) => const Align(
                alignment: Alignment.centerLeft,
                child: Text('Projet courant indisponible.'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: spacesAsync.when(
                data: (spaces) {
                  final lines = quantityService.buildLines(spaces);

                  return selectedProjectAsync.when(
                    data: (project) {
                      return Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1820,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Espace')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Sol')),
                                DataColumn(label: Text('Plafond')),
                                DataColumn(label: Text('Murs bruts')),
                                DataColumn(label: Text('Ouvertures')),
                                DataColumn(label: Text('Murs nets')),
                                DataColumn(label: Text('Périmètre')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: [
                                for (final line in lines)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(line.spaceName)),
                                      DataCell(Text(line.spaceType)),
                                      DataCell(Text(
                                          line.floorArea.toStringAsFixed(2))),
                                      DataCell(Text(
                                          line.ceilingArea.toStringAsFixed(2))),
                                      DataCell(Text(line.grossWallArea
                                          .toStringAsFixed(2))),
                                      DataCell(Text(line.openingsArea
                                          .toStringAsFixed(2))),
                                      DataCell(Text(
                                          line.netWallArea.toStringAsFixed(2))),
                                      DataCell(Text(
                                          line.perimeter.toStringAsFixed(2))),
                                      DataCell(
                                        ElevatedButton.icon(
                                          onPressed: project == null
                                              ? null
                                              : () =>
                                                  _openGeneratePurchaseDialog(
                                                    context,
                                                    ref,
                                                    line: line,
                                                    projectId: project.id,
                                                    projectName: project.name,
                                                  ),
                                          icon: const Icon(
                                              Icons.shopping_cart_outlined),
                                          label: const Text('Générer achat'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('Erreur projet: $error')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erreur: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
