import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/project.dart';
import '../../../../shared/presentation/premium_ui.dart';
import '../../../checklist/presentation/checklist_page.dart';
import '../../../factures/presentation/providers/invoices_providers.dart';

/// Tableau de bord : encaissements du chantier et choses à faire. Les
/// chiffres se mettent à jour à chaque nouvelle facture, paiement ou
/// élément de check-list (actualisation automatique).
class FinanceChecklistCard extends ConsumerWidget {
  const FinanceChecklistCard({super.key, required this.project});

  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.compact(locale: 'fr_FR');
    final project = this.project;
    final invoices =
        project == null ? null : ref.watch(projectInvoicesProvider(project.id));
    final checklist = ref.watch(checklistItemsProvider(project?.id)).value;

    final tiles = <Widget>[];
    final data = invoices?.value;
    if (data != null) {
      var billed = 0.0;
      var paid = 0.0;
      var overdue = 0;
      for (final i in data.invoices
          .where((i) => i.status != 'annulee' && i.status != 'brouillon')) {
        final t = data.totalsOf(i);
        billed += t.ttc;
        paid += i.amountPaid;
        if (i.isOverdue(t.ttc)) {
          overdue++;
        }
      }
      final due = (billed - paid).clamp(0, double.infinity);
      tiles.addAll([
        PremiumMetricTile(
          label: 'Facturé TTC',
          value: '${money.format(billed)} DA',
          icon: Icons.receipt_long_outlined,
          onTap: () => context.go('/factures'),
        ),
        PremiumMetricTile(
          label: 'Reste à encaisser',
          value: '${money.format(due)} DA',
          icon: Icons.hourglass_bottom_outlined,
          onTap: () => context.go('/factures'),
        ),
        PremiumMetricTile(
          label: 'Factures en retard',
          value: '$overdue',
          icon: Icons.warning_amber_outlined,
          onTap: () => context.go('/factures'),
        ),
      ]);
    }
    if (checklist != null) {
      final todo = checklist.where((i) => !i.isDone).toList();
      final late = todo.where((i) => i.isOverdue()).length;
      tiles.addAll([
        PremiumMetricTile(
          label: 'Check-list à faire',
          value: '${todo.length}',
          icon: Icons.checklist_rtl_outlined,
          onTap: () => context.go('/checklist'),
        ),
        if (late > 0)
          PremiumMetricTile(
            label: 'Check-list en retard',
            value: '$late',
            icon: Icons.alarm_outlined,
            onTap: () => context.go('/checklist'),
          ),
      ]);
    }
    if (tiles.isEmpty) {
      // Tables pas encore créées ou chargement : rien à afficher.
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PremiumSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSectionHeader(
              title: 'Facturation et check-list',
              subtitle: project == null
                  ? 'Choisis un chantier pour suivre ses encaissements'
                  : 'Encaissements de ${project.name} et choses à faire',
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: tiles),
          ],
        ),
      ),
    );
  }
}
