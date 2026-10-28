import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import 'providers/purchases_providers.dart';
import 'widgets/purchase_form.dart';

/// Une ligne proposée dans un achat généré (depuis le module Technique,
/// le Quantitatif…).
class PurchaseDraftLine {
  const PurchaseDraftLine({
    required this.article,
    required this.quantity,
    required this.unit,
    this.description = '',
  });

  final String article;
  final double quantity;
  final String unit;
  final String description;
}

/// Ouvre le formulaire d'achat prérempli (lignes, titre, lot). L'utilisateur
/// choisit le fournisseur, ajuste les quantités et les prix, puis
/// enregistre l'achat en brouillon.
Future<void> showPurchaseDraftDialog(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String projectName,
  required String title,
  required String lot,
  required String notes,
  required List<PurchaseDraftLine> lines,
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

  final now = DateTime.now();
  Purchase draft({String? supplierId, String? t, String? l, String? n}) =>
      Purchase(
        id: '',
        companyId: profile.companyId,
        projectId: projectId,
        title: t ?? title,
        lot: l ?? lot,
        notes: n ?? notes,
        supplierId: supplierId,
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
        createdAt: now,
        updatedAt: now,
      );
  final items = [
    for (var i = 0; i < lines.length; i++)
      PurchaseItem(
        id: '',
        purchaseId: '',
        article: lines[i].article,
        description: lines[i].description,
        quantity: lines[i].quantity,
        unit: lines[i].unit,
        unitPrice: 0,
        notes: '',
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      ),
  ];

  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          child: PurchaseForm(
            projectOptions: [
              DropdownMenuItem<String>(
                value: projectId,
                child: Text(projectName),
              ),
            ],
            initialPurchase: draft(),
            initialItems: items,
            onSubmit: (value) async {
              await ref.read(purchasesRepositoryProvider).createPurchase(
                    draft(
                      supplierId: value.supplierId,
                      t: value.title,
                      l: value.lot,
                      n: value.notes,
                    ),
                    value.items,
                  );
              ref.invalidate(activePurchasesProvider);
              ref.invalidate(archivedPurchasesProvider);
              // Le formulaire ferme lui-même la fenêtre après l'envoi : la
              // fermer ici aussi retirait la page dessous (écran noir).
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Achat créé en brouillon (module Achats).'),
                  ),
                );
              }
            },
          ),
        ),
      ),
    ),
  );
}
