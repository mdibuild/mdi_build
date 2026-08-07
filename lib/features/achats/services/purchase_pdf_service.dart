import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';

class PurchasePdfService {
  Future<void> printPurchase({
    required Purchase purchase,
    required String projectName,
    required List<PurchaseItem> items,
  }) async {
    final pdf = pw.Document();
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildHeader(
            purchase: purchase,
            projectName: projectName,
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 16),
          _buildInfoCard(
            purchase: purchase,
            projectName: projectName,
          ),
          pw.SizedBox(height: 16),
          _buildItemsTable(items),
          pw.SizedBox(height: 16),
          _buildTotalCard(total),
          if (purchase.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotesCard(purchase.notes.trim()),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _buildHeader({
    required Purchase purchase,
    required String projectName,
    required String generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BON D’ACHAT',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  purchase.title,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Projet : $projectName',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date édition : $generatedAt',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoCard({
    required Purchase purchase,
    required String projectName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          _line('Titre', purchase.title),
          _line('Projet', projectName),
          _line('Lot', purchase.lot),
          _line('Statut', _statusLabel(purchase.status)),
          _line(
            'Observations',
            purchase.notes.trim().isEmpty ? '-' : purchase.notes.trim(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(List<PurchaseItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Article', bold: true),
            _cell('Quantité', bold: true),
            _cell('PU', bold: true),
            _cell('Total', bold: true),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _cell(
                item.description.trim().isEmpty
                    ? item.article
                    : '${item.article}\n${item.description.trim()}',
              ),
              _cell('${item.quantity.toStringAsFixed(2)} ${item.unit}'),
              _cell(item.unitPrice.toStringAsFixed(2)),
              _cell(item.total.toStringAsFixed(2)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTotalCard(double total) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.grey500),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'TOTAL',
                style: const pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              total.toStringAsFixed(2),
              style: const pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildNotesCard(String notes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Remarques',
            style: const pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(notes),
        ],
      ),
    );
  }

  pw.Widget _line(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label :',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'dg_valide':
        return 'DG validé';
      case 'commande':
        return 'Commandé';
      case 'livre':
        return 'Livré';
      case 'annule':
        return 'Annulé';
      case 'archive':
        return 'Archivé';
      default:
        return status;
    }
  }
}
