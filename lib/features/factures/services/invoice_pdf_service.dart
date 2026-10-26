import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/client.dart';
import '../../../core/models/company.dart';
import '../../../core/models/project_invoice.dart';
import '../../../core/services/amount_in_words.dart';
import '../../../core/services/party_details.dart';
import '../../../core/services/pdf_letterhead.dart';
import '../../../core/models/document_layout.dart';

/// Montant au format français : 1 250 080,50.
String formatMoney(double value) => NumberFormat('#,##0.00', 'fr_FR')
    .format(value)
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

class InvoicePdfService {
  Future<Uint8List> buildInvoicePdf({
    required ProjectInvoice invoice,
    required List<InvoiceLineItem> items,
    required String projectName,
    String? projectLocation,
    Client? client,
    String? fallbackClientName,
    Company? company,
    Uint8List? logoBytes,
  }) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final totals = InvoiceTotals(items, invoice.taxRate, invoice.amountPaid,
        globalDiscountPercent: invoice.discountPercent);
    final hidden = LineColumn.fromKeys(invoice.hiddenColumns);
    final day = DateFormat('dd/MM/yyyy');
    final clientName = client?.name ?? (fallbackClientName ?? '').trim();
    final clientLines =
        client == null ? const <String>[] : clientDetailLines(client);

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          PdfLetterhead.header(
            company: company,
            logoBytes: logoBytes,
            documentTitle: 'FACTURE',
            boldFont: bold,
            regularFont: regular,
            trailing: [
              pw.SizedBox(height: 4),
              pw.Text(
                'N° ${invoice.number}',
                style: pw.TextStyle(font: bold, fontSize: 11),
              ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            label('FACTURÉ À'),
                            value(clientName.isEmpty ? '-' : clientName),
                            if (clientLines.isNotEmpty)
                              pw.Text(
                                clientLines.join('\n'),
                                style: const pw.TextStyle(
                                    fontSize: 9, lineSpacing: 1.5),
                              ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 18),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          label('OBJET'),
                          value(invoice.title),
                          label('CHANTIER'),
                          value([
                            projectName,
                            if ((projectLocation ?? '').trim().isNotEmpty)
                              projectLocation!.trim(),
                          ].join(' — ')),
                          label('DATE / ÉCHÉANCE'),
                          value('${day.format(invoice.issueDate)} · '
                              '${invoice.dueDate == null ? 'à réception' : day.format(invoice.dueDate!)}'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                _itemsTable(items, hidden),
                pw.SizedBox(height: 14),
                _totals(totals),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Arrêtée la présente facture à la somme de : '
                  '${amountInWordsDzd(totals.ttc)} (TTC).',
                  style: pw.TextStyle(font: bold, fontSize: 9.5),
                ),
                if (_bankLine(company).isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Règlement : ${_bankLine(company)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
                if (invoice.notes.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    invoice.notes.trim(),
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey800),
                  ),
                ],
                pw.SizedBox(height: 24),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Cachet et signature',
                    style: pw.TextStyle(font: bold, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 60),
              ],
            ),
          ),
          PdfLetterhead.footer(
            company: company,
            boldFont: bold,
            regularFont: regular,
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> printInvoice(Uint8List bytes, ProjectInvoice invoice) =>
      Printing.layoutPdf(
        name: 'facture_${invoice.number}.pdf',
        onLayout: (_) async => bytes,
      );

  Future<void> shareInvoice(Uint8List bytes, ProjectInvoice invoice) =>
      Printing.sharePdf(
          bytes: bytes, filename: 'facture_${invoice.number}.pdf');

  static String _bankLine(Company? company) {
    final bank = company?.bankName.trim() ?? '';
    final rib = company?.bankRib.trim() ?? '';
    return [
      if (bank.isNotEmpty) bank,
      if (rib.isNotEmpty) 'RIB $rib',
    ].join(' · ');
  }

  pw.Widget _itemsTable(List<InvoiceLineItem> items, Set<LineColumn> hidden) {
    pw.Widget cell(String text, {bool bold = false, bool right = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 9.5,
              color: bold ? PdfLetterhead.ink : PdfColors.black,
            ),
          ),
        );
    bool show(LineColumn c) => !hidden.contains(c);
    final anyDiscount = items.any((i) => i.discountPercent != 0);
    final columns = <(String, double, bool, String Function(InvoiceLineItem))>[
      ('Désignation', 4, false, (i) => i.label),
      if (show(LineColumn.quantity))
        ('Qté', 1.2, true, (i) => _qty(i.quantity)),
      if (show(LineColumn.unit)) ('Unité', 1, false, (i) => i.unit),
      if (show(LineColumn.unitPrice))
        ('PU HT', 1.6, true, (i) => formatMoney(i.unitPrice)),
      if (show(LineColumn.discount) && anyDiscount)
        (
          'Remise',
          1,
          true,
          (i) => i.discountPercent == 0 ? '-' : '${_qty(i.discountPercent)} %'
        ),
      if (show(LineColumn.total))
        ('Total HT', 1.7, true, (i) => formatMoney(i.total)),
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
          children: [
            for (final c in columns) cell(c.$1, bold: true, right: c.$3),
          ],
        ),
        for (final item in items)
          pw.TableRow(children: [
            for (final c in columns) cell(c.$4(item), right: c.$3),
          ]),
      ],
    );
  }

  static String _qty(double q) => q == q.roundToDouble()
      ? q.toStringAsFixed(0)
      : NumberFormat('0.###', 'fr_FR').format(q);

  pw.Widget _totals(InvoiceTotals t) {
    pw.Widget line(String label, double value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text('${formatMoney(value)} DA',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ]),
        );
    final rate = t.rate == t.rate.roundToDouble()
        ? t.rate.toStringAsFixed(0)
        : t.rate.toStringAsFixed(2);
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 270,
        child: pw.Column(children: [
          if (t.document.hasDiscount) ...[
            line('Total brut HT', t.document.gross),
            if (t.document.lineDiscounts > 0.004)
              line('Remises sur lignes', -t.document.lineDiscounts),
            if (t.document.globalDiscount > 0.004)
              line('Remise globale ${_qty(t.document.globalDiscountPercent)} %',
                  -t.document.globalDiscount),
          ],
          line('Total HT', t.ht, bold: t.document.hasDiscount),
          line('TVA $rate %', t.tax),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6, bottom: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfLetterhead.ink, width: PdfLetterhead.frameWidth),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: line('TOTAL TTC', t.ttc, bold: true),
          ),
          if (t.amountPaid > 0) ...[
            line('Déjà réglé', t.amountPaid),
            line('Reste à payer', t.remaining, bold: true),
          ],
        ]),
      ),
    );
  }
}
