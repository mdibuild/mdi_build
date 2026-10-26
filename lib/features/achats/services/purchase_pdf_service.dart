import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/company.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/project_document.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/models/purchase_workflow.dart';
import '../../../core/models/supplier.dart';
import '../../../core/services/party_details.dart';
import '../../../core/services/pdf_letterhead.dart';

class PurchasePdfService {
  Future<void> printPurchase({
    required Purchase purchase,
    required String projectName,
    required List<PurchaseItem> items,
    Company? company,
    Uint8List? logoBytes,
    Supplier? supplier,
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          PdfLetterhead.header(
            company: company,
            logoBytes: logoBytes,
            documentTitle: 'BON D’ACHAT',
            boldFont: boldFont,
            regularFont: regularFont,
            trailing: [
              pw.SizedBox(height: 4),
              pw.Text(
                'Édité le $generatedAt',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 9,
                  color: PdfColors.grey300,
                ),
              ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  purchase: purchase,
                  projectName: projectName,
                  supplier: supplier,
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
          ),
          PdfLetterhead.footer(
            company: company,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _buildInfoCard({
    required Purchase purchase,
    required String projectName,
    Supplier? supplier,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          if (purchase.orderNumber != null)
            _line('N° commande', purchase.orderNumber!),
          _line('Titre', purchase.title),
          _line('Projet', projectName),
          _line('Lot', purchase.lot),
          _line('Fournisseur', supplier?.name ?? '-'),
          if (supplier != null)
            for (final detail in supplierDetailLines(supplier))
              _line('', detail),
          _line('Statut', _statusLabel(purchase.status)),
          _line(
            'Observations',
            purchase.notes.trim().isEmpty ? '-' : purchase.notes.trim(),
          ),
        ],
      ),
    );
  }

  /// État complet d'un achat pour un rapport : commande, fournisseur,
  /// articles, historique du suivi et pièces jointes (devis / proforma du
  /// fournisseur) reproduites en image.
  Future<void> printPurchaseState({
    required Purchase purchase,
    required String projectName,
    required List<PurchaseItem> items,
    required List<PurchaseEvent> events,
    required List<(ProjectDocument, Uint8List?)> attachments,
    Company? company,
    Uint8List? logoBytes,
    Supplier? supplier,
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    final stamp = DateFormat('dd/MM/yyyy HH:mm');

    // Pièces jointes converties en images (photos telles quelles, PDF :
    // 3 premières pages).
    final pictures = <(ProjectDocument, List<Uint8List>)>[];
    for (final (doc, bytes) in attachments) {
      if (bytes == null) {
        pictures.add((doc, const []));
      } else if (doc.isImage) {
        pictures.add((doc, [bytes]));
      } else if (doc.isPdf) {
        final pages = <Uint8List>[];
        try {
          await for (final page
              in Printing.raster(bytes, pages: const [0, 1, 2], dpi: 110)) {
            pages.add(await page.toPng());
          }
        } catch (_) {
          // PDF illisible : seule sa référence est listée.
        }
        pictures.add((doc, pages));
      } else {
        pictures.add((doc, const []));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          PdfLetterhead.header(
            company: company,
            logoBytes: logoBytes,
            documentTitle: 'ÉTAT DE L’ACHAT',
            boldFont: boldFont,
            regularFont: regularFont,
            trailing: [
              pw.SizedBox(height: 4),
              pw.Text(
                purchase.orderNumber == null
                    ? 'Édité le ${stamp.format(DateTime.now())}'
                    : 'Commande ${purchase.orderNumber}',
                style: pw.TextStyle(font: boldFont, fontSize: 10),
              ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(
                  purchase: purchase,
                  projectName: projectName,
                  supplier: supplier,
                ),
                pw.SizedBox(height: 14),
                PdfLetterhead.sectionBar('ARTICLES', boldFont: boldFont),
                _buildItemsTable(items),
                pw.SizedBox(height: 10),
                _buildTotalCard(total),
                pw.SizedBox(height: 16),
                PdfLetterhead.sectionBar('SUIVI DE L’ACHAT',
                    boldFont: boldFont),
                pw.SizedBox(height: 6),
                if (events.isEmpty)
                  pw.Text('Aucun évènement enregistré.',
                      style: const pw.TextStyle(fontSize: 9))
                else
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.6),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1.6),
                      1: pw.FlexColumnWidth(1.8),
                      2: pw.FlexColumnWidth(1.6),
                      3: pw.FlexColumnWidth(3),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _cell('Date', bold: true),
                          _cell('Étape', bold: true),
                          _cell('Par', bold: true),
                          _cell('Détail', bold: true),
                        ],
                      ),
                      for (final e in events)
                        pw.TableRow(children: [
                          _cell(stamp.format(e.createdAt.toLocal())),
                          _cell(e.title),
                          _cell(e.actorName.isEmpty ? '-' : e.actorName),
                          _cell(e.comment.isEmpty ? '-' : e.comment),
                        ]),
                    ],
                  ),
                pw.SizedBox(height: 16),
                PdfLetterhead.sectionBar('PIÈCES JOINTES (DEVIS / PROFORMA)',
                    boldFont: boldFont),
                pw.SizedBox(height: 6),
                if (pictures.isEmpty)
                  pw.Text('Aucune pièce jointe.',
                      style: const pw.TextStyle(fontSize: 9)),
                for (final (doc, images) in pictures) ...[
                  pw.Text(
                    '${doc.title} — ${doc.fileName}',
                    style: pw.TextStyle(font: boldFont, fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  if (images.isEmpty)
                    pw.Text(
                      'Aperçu non disponible : fichier à consulter dans '
                      'l’application.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  for (final image in images)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      height: 560,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Image(pw.MemoryImage(image),
                          fit: pw.BoxFit.contain),
                    ),
                  pw.SizedBox(height: 8),
                ],
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

    await Printing.layoutPdf(
      name: 'etat_achat_${purchase.orderNumber ?? purchase.title}.pdf',
      onLayout: (format) async => pdf.save(),
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
              label.isEmpty ? '' : '$label :',
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

  String _statusLabel(String status) => PurchaseWorkflow.label(status);
}
