import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/estimate_item.dart';

class QuotePdfService {
  Future<Uint8List> buildQuotePdf({
    required String projectName,
    required String mode,
    required String status,
    required double unitPriceWalls,
    required double unitPriceCeiling,
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.19;
    final total = subtotal + tax;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildHeader(
            projectName: projectName,
            mode: mode,
            status: status,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 16),
          _buildPricingCard(
            unitPriceWalls: unitPriceWalls,
            unitPriceCeiling: unitPriceCeiling,
          ),
          pw.SizedBox(height: 16),
          _buildItemsTable(items),
          pw.SizedBox(height: 16),
          _buildTotals(
            subtotal: subtotal,
            tax: tax,
            total: total,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 24),
          _buildSignature(
            signatureBytes,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printQuote({
    required String projectName,
    required String mode,
    required String status,
    required double unitPriceWalls,
    required double unitPriceCeiling,
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
  }) async {
    final bytes = await buildQuotePdf(
      projectName: projectName,
      mode: mode,
      status: status,
      unitPriceWalls: unitPriceWalls,
      unitPriceCeiling: unitPriceCeiling,
      items: items,
      signatureBytes: signatureBytes,
    );

    await Printing.layoutPdf(
      name: 'devis_$projectName.pdf',
      onLayout: (format) async => bytes,
    );
  }

  Future<void> shareQuote({
    required String projectName,
    required String mode,
    required String status,
    required double unitPriceWalls,
    required double unitPriceCeiling,
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
  }) async {
    final bytes = await buildQuotePdf(
      projectName: projectName,
      mode: mode,
      status: status,
      unitPriceWalls: unitPriceWalls,
      unitPriceCeiling: unitPriceCeiling,
      items: items,
      signatureBytes: signatureBytes,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'devis_$projectName.pdf',
    );
  }

  pw.Widget _buildHeader({
    required String projectName,
    required String mode,
    required String status,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DEVIS',
            style: pw.TextStyle(
              font: boldFont,
              color: PdfColors.white,
              fontSize: 22,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Projet : $projectName',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Mode : ${_modeLabel(mode)}',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Statut : ${_statusLabel(status)}',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPricingCard({
    required double unitPriceWalls,
    required double unitPriceCeiling,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'PU peinture murs : ${unitPriceWalls.toStringAsFixed(2)}',
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              'PU peinture plafond : ${unitPriceCeiling.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(List<EstimateItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('Désignation', bold: true),
            _cell('Qté', bold: true),
            _cell('Unité', bold: true),
            _cell('PU', bold: true),
            _cell('Total', bold: true),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            children: [
              _cell(item.label),
              _cell(item.quantity.toStringAsFixed(2)),
              _cell(item.unit),
              _cell(item.unitPrice.toStringAsFixed(2)),
              _cell(item.total.toStringAsFixed(2)),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildTotals({
    required double subtotal,
    required double tax,
    required double total,
    required pw.Font boldFont,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _totalLine('Sous-total', subtotal),
            pw.SizedBox(height: 6),
            _totalLine('TVA 19 %', tax),
            pw.Divider(color: PdfColors.grey500),
            _totalLine('Total', total, bold: true, boldFont: boldFont),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSignature(
    Uint8List? signatureBytes, {
    required pw.Font boldFont,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Signature client',
            style: pw.TextStyle(font: boldFont),
          ),
          pw.SizedBox(height: 8),
          if (signatureBytes == null)
            pw.Text('Aucune signature enregistrée.')
          else
            pw.Image(
              pw.MemoryImage(signatureBytes),
              height: 120,
              fit: pw.BoxFit.contain,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'Document généré depuis le module Devis.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  pw.Widget _cell(String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _totalLine(
    String label,
    double value, {
    bool bold = false,
    pw.Font? boldFont,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: bold ? boldFont : null,
            ),
          ),
        ),
        pw.Text(
          value.toStringAsFixed(2),
          style: pw.TextStyle(
            font: bold ? boldFont : null,
          ),
        ),
      ],
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'piece':
        return 'Par pièce';
      case 'corps_etat':
        return 'Par corps dâDAÃ¢âDAž¢état';
      case 'mixte':
        return 'Mixte';
      default:
        return mode;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'envoye':
        return 'Envoyé';
      case 'signe':
        return 'Signé';
      default:
        return status;
    }
  }
}
