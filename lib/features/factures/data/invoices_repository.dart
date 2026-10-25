import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/project_invoice.dart';
import '../../../core/services/supabase_service.dart';

class InvoicesRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ProjectInvoice>> fetchInvoicesByProject(String projectId) async {
    final rows = await _client
        .from('project_invoices')
        .select()
        .eq('project_id', projectId)
        .order('issue_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => ProjectInvoice.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectInvoice?> fetchInvoiceById(String id) async {
    final row = await _client
        .from('project_invoices')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ProjectInvoice.fromMap(row);
  }

  Future<List<InvoiceLineItem>> fetchInvoiceItems(String invoiceId) async {
    final rows = await _client
        .from('project_invoice_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('sort_order', ascending: true);
    return (rows as List<dynamic>)
        .map((row) => InvoiceLineItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Toutes les lignes des factures données (une seule requête).
  Future<Map<String, List<InvoiceLineItem>>> fetchItemsForInvoices(
      List<String> invoiceIds) async {
    if (invoiceIds.isEmpty) {
      return {};
    }
    final rows = await _client
        .from('project_invoice_items')
        .select()
        .inFilter('invoice_id', invoiceIds)
        .order('sort_order', ascending: true);
    final result = <String, List<InvoiceLineItem>>{};
    for (final row in rows as List<dynamic>) {
      final item = InvoiceLineItem.fromMap(row as Map<String, dynamic>);
      result.putIfAbsent(item.invoiceId, () => []).add(item);
    }
    return result;
  }

  /// Numéro suivant pour l'entreprise et l'année de la facture.
  Future<String> nextNumber(String companyId, int year) async {
    final rows = await _client
        .from('project_invoices')
        .select('number')
        .eq('company_id', companyId)
        .like('number', 'FAC-$year-%');
    return nextInvoiceNumber(
      (rows as List<dynamic>).map((r) => (r as Map)['number'].toString()),
      year,
    );
  }

  /// Crée la facture ; si le numéro vient d'être pris par un collègue,
  /// un nouveau numéro est calculé (2 essais).
  Future<ProjectInvoice> createInvoice(
    ProjectInvoice invoice,
    List<InvoiceLineItem> items,
  ) async {
    var attempt = invoice;
    for (var i = 0; i < 2; i++) {
      try {
        final row = await _client
            .from('project_invoices')
            .insert(attempt.toInsertMap())
            .select()
            .single();
        final saved = ProjectInvoice.fromMap(row);
        await _replaceItems(saved.id, items);
        return saved;
      } on PostgrestException catch (error) {
        if (error.code != '23505' || i == 1) {
          rethrow;
        }
        attempt = attempt.copyWith(
          number: await nextNumber(attempt.companyId, attempt.issueDate.year),
        );
      }
    }
    throw StateError('Numéro de facture indisponible');
  }

  Future<ProjectInvoice> updateInvoice(
    ProjectInvoice invoice,
    List<InvoiceLineItem> items,
  ) async {
    final row = await _client
        .from('project_invoices')
        .update(invoice.toUpdateMap())
        .eq('id', invoice.id)
        .select()
        .single();
    final saved = ProjectInvoice.fromMap(row);
    await _replaceItems(saved.id, items);
    return saved;
  }

  /// Met à jour uniquement l'en-tête (paiement, statut) sans toucher aux
  /// lignes.
  Future<ProjectInvoice> updateHeader(ProjectInvoice invoice) async {
    final row = await _client
        .from('project_invoices')
        .update(invoice.toUpdateMap())
        .eq('id', invoice.id)
        .select()
        .single();
    return ProjectInvoice.fromMap(row);
  }

  Future<void> _replaceItems(
      String invoiceId, List<InvoiceLineItem> items) async {
    await _client
        .from('project_invoice_items')
        .delete()
        .eq('invoice_id', invoiceId);
    if (items.isEmpty) {
      return;
    }
    await _client.from('project_invoice_items').insert([
      for (var i = 0; i < items.length; i++) items[i].toInsertMap(invoiceId, i),
    ]);
  }

  Future<void> deleteInvoice(String id) async {
    await _client.from('project_invoices').delete().eq('id', id);
  }
}
