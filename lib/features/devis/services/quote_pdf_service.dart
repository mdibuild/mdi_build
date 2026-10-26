import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/company.dart';
import '../../../core/models/document_layout.dart';
import '../../../core/models/estimate_item.dart';
import '../../../core/services/pdf_letterhead.dart';

class QuotePdfService {
  QuotePdfService(
      {this.hiddenColumns = const {}, this.globalDiscountPercent = 0});

  /// Colonnes masquées sur le PDF (la désignation reste affichée).
  final Set<LineColumn> hiddenColumns;

  /// Remise globale (%) appliquée après les remises de ligne.
  final double globalDiscountPercent;

  Future<Uint8List> buildQuotePdf({
    required String projectName,
    required String mode,
    required String status,
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
    Company? company,
    Uint8List? logoBytes,
    String? clientName,
    String? location,
    List<String> clientDetails = const [],
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    final totals = DocumentTotals(
      [
        for (final i in items)
          PricedLine(
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            discountPercent: i.discountPercent,
          ),
      ],
      globalDiscountPercent: globalDiscountPercent,
    );
    final issuedAt = DateFormat('dd/MM/yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          PdfLetterhead.header(
            company: company,
            logoBytes: logoBytes,
            documentTitle: 'DEVIS',
            boldFont: boldFont,
            regularFont: regularFont,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaRow(
                  clientName: clientName,
                  location: location,
                  clientDetails: clientDetails,
                  projectName: projectName,
                  mode: mode,
                  status: status,
                  issuedAt: issuedAt,
                ),
                pw.SizedBox(height: 18),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                PdfLetterhead.sectionBar(
                  'DESCRIPTION DES TRAVAUX',
                  boldFont: boldFont,
                ),
                _buildItemsTable(items),
                pw.SizedBox(height: 10),
                _buildTotals(totals),
                pw.SizedBox(height: 20),
                PdfLetterhead.sectionBar(
                  'CONDITIONS GÉNÉRALES',
                  boldFont: boldFont,
                ),
                pw.SizedBox(height: 8),
                _buildTerms(),
                pw.SizedBox(height: 20),
                _buildSignature(signatureBytes, boldFont: boldFont),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
          PdfLetterhead.footer(
            company: company,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printQuote({
    required String projectName,
    required String mode,
    required String status,
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
    Company? company,
    Uint8List? logoBytes,
    String? clientName,
    String? location,
    List<String> clientDetails = const [],
  }) async {
    final bytes = await buildQuotePdf(
      projectName: projectName,
      mode: mode,
      status: status,
      items: items,
      signatureBytes: signatureBytes,
      company: company,
      logoBytes: logoBytes,
      clientName: clientName,
      location: location,
      clientDetails: clientDetails,
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
    required List<EstimateItem> items,
    Uint8List? signatureBytes,
    Company? company,
    Uint8List? logoBytes,
    String? clientName,
    String? location,
    List<String> clientDetails = const [],
  }) async {
    final bytes = await buildQuotePdf(
      projectName: projectName,
      mode: mode,
      status: status,
      items: items,
      signatureBytes: signatureBytes,
      company: company,
      logoBytes: logoBytes,
      clientName: clientName,
      location: location,
      clientDetails: clientDetails,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'devis_$projectName.pdf',
    );
  }

  pw.Widget _buildMetaRow({
    String? clientName,
    String? location,
    List<String> clientDetails = const [],
    required String projectName,
    required String mode,
    required String status,
    required String issuedAt,
  }) {
    pw.Widget label(String text) => pw.Text(
          text,
          style: const pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: PdfLetterhead.ink,
            letterSpacing: 0.5,
          ),
        );
    pw.Widget value(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 10.5)),
        );

    final trimmedClient = clientName?.trim() ?? '';
    final trimmedLocation = location?.trim() ?? '';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              label('CLIENT'),
              value(trimmedClient.isEmpty ? '-' : trimmedClient),
              if (clientDetails.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    clientDetails.join('\n'),
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
                  ),
                ),
              if (trimmedLocation.isNotEmpty) ...[
                label('ADRESSE DU CHANTIER'),
                value(trimmedLocation),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              label('PROJET'),
              value(projectName),
              label('DATE'),
              value(issuedAt),
              label('MODE / STATUT'),
              value('${_modeLabel(mode)} · ${_statusLabel(status)}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(List<EstimateItem> items) {
    bool show(LineColumn c) => !hiddenColumns.contains(c);
    final anyDiscount = items.any((i) => i.discountPercent != 0);
    final columns = <(String, double, String Function(EstimateItem))>[
      ('Désignation', 4, (i) => i.label),
      if (show(LineColumn.quantity)) ('Qté', 1.2, (i) => _qty(i.quantity)),
      if (show(LineColumn.unit)) ('Unité', 1, (i) => i.unit),
      if (show(LineColumn.unitPrice))
        ('PU HT', 1.4, (i) => _money(i.unitPrice)),
      if (show(LineColumn.discount) && anyDiscount)
        (
          'Remise',
          1,
          (i) => i.discountPercent == 0 ? '-' : '${_qty(i.discountPercent)} %'
        ),
      if (show(LineColumn.total)) ('Montant HT', 1.6, (i) => _money(i.total)),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: {
        for (var c = 0; c < columns.length; c++)
          c: pw.FlexColumnWidth(columns[c].$2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [for (final c in columns) _cell(c.$1, bold: true)],
        ),
        for (final item in items)
          pw.TableRow(children: [for (final c in columns) _cell(c.$3(item))]),
      ],
    );
  }

  static String _qty(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');

  static String _money(double v) => NumberFormat('#,##0.00', 'fr_FR')
      .format(v)
      .replaceAll('\u202f', ' ')
      .replaceAll('\u00a0', ' ');

  pw.Widget _buildTotals(DocumentTotals t) {
    final rate = t.taxRatePercent == t.taxRatePercent.roundToDouble()
        ? t.taxRatePercent.toStringAsFixed(0)
        : t.taxRatePercent.toStringAsFixed(2);
    final total = t.ttc;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 240,
          child: pw.Column(
            children: [
              if (t.hasDiscount) ...[
                _totalLine('Total brut HT', t.gross),
                if (t.lineDiscounts > 0.004)
                  _totalLine('Remises sur lignes', -t.lineDiscounts),
                if (t.globalDiscount > 0.004)
                  _totalLine(
                      'Remise globale ${_qty(t.globalDiscountPercent)} %',
                      -t.globalDiscount),
                pw.SizedBox(height: 4),
              ],
              _totalLine('Total HT', t.netHt, bold: true),
              pw.SizedBox(height: 4),
              _totalLine('TVA $rate %', t.tax),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfLetterhead.ink,
              width: PdfLetterhead.frameWidth,
            ),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'TOTAL DEVIS',
                  style: const pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfLetterhead.ink,
                  ),
                ),
              ),
              pw.Text(
                '${_money(total)} DA',
                style: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                  color: PdfLetterhead.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTerms() {
    const terms = [
      'Ce devis est valable 30 jours à compter de sa date d\'émission.',
      'Un acompte peut être demandé à la signature pour le démarrage des travaux.',
      'Toute modification du périmètre des travaux fera l\'objet d\'un avenant.',
      'Le solde est exigible à la réception des travaux.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < terms.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(
              '${i + 1}. ${terms[i]}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ),
      ],
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
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Signature client',
            style: pw.TextStyle(font: boldFont, fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          if (signatureBytes == null)
            pw.Text(
              'Aucune signature enregistrée.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            )
          else
            pw.Image(
              pw.MemoryImage(signatureBytes),
              height: 110,
              fit: pw.BoxFit.contain,
            ),
        ],
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
          color: bold ? PdfLetterhead.ink : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _totalLine(String label, double value, {bool bold = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 10,
            ),
          ),
        ),
        pw.Text(
          '${_money(value)} DA',
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10,
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
        return 'Par corps d’état';
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
