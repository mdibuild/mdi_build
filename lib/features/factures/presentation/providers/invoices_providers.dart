import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_invoice.dart';
import '../../../../core/providers/module_refresh_provider.dart';
import '../../data/invoices_repository.dart';
import '../../../projects/presentation/providers/project_scope_provider.dart';

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository();
});

/// Factures d'un chantier avec leurs lignes (pour afficher les totaux sans
/// une requête par facture).
class ProjectInvoicesData {
  const ProjectInvoicesData(this.invoices, this.itemsByInvoice);

  final List<ProjectInvoice> invoices;
  final Map<String, List<InvoiceLineItem>> itemsByInvoice;

  InvoiceTotals totalsOf(ProjectInvoice invoice) => InvoiceTotals(
        itemsByInvoice[invoice.id] ?? const [],
        invoice.taxRate,
        invoice.amountPaid,
        globalDiscountPercent: invoice.discountPercent,
      );
}

final projectInvoicesProvider =
    FutureProvider.family<ProjectInvoicesData, String>((ref, projectId) async {
  ref.watch(moduleRefreshRevisionProvider);
  final repository = ref.read(invoicesRepositoryProvider);
  final invoices = await repository.fetchInvoicesByProject(projectId);
  final items =
      await repository.fetchItemsForInvoices([for (final i in invoices) i.id]);
  return ProjectInvoicesData(invoices, items);
});

/// Factures du chantier sélectionné, ou de tous les projets.
final scopedInvoicesProvider = FutureProvider<ProjectInvoicesData>((ref) async {
  final projects = await ref.watch(scopedProjectsProvider.future);
  final all = await Future.wait([
    for (final p in projects) ref.watch(projectInvoicesProvider(p.id).future),
  ]);
  return ProjectInvoicesData(
    [for (final d in all) ...d.invoices]
      ..sort((a, b) => b.issueDate.compareTo(a.issueDate)),
    {for (final d in all) ...d.itemsByInvoice},
  );
});
