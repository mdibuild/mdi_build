import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/company.dart';
import '../../features/settings/data/company_repository.dart';

/// En-tête/pied de page "entreprise" partagé par tous les documents imprimés
/// (devis, achats, rapports). Chaque société voit son propre logo et ses
/// propres coordonnées apparaître automatiquement, sans étape manuelle.
class PdfLetterhead {
  PdfLetterhead._();

  static const ink = PdfColor.fromInt(0xFF0B2436);
  static const gold = PdfColor.fromInt(0xFFE7B800);
  static const goldSoft = PdfColor.fromInt(0xFFF7E9B8);

  static Future<Uint8List?> fetchLogoBytes(Company? company) async {
    final path = company?.logoPath;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    try {
      final url = CompanyRepository().publicLogoUrl(path);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Un logo indisponible ne doit jamais empêcher la génération du document.
    }
    return null;
  }

  static String companyName(Company? company) {
    final name = company?.name.trim() ?? '';
    return name.isEmpty ? 'Mon entreprise' : name;
  }

  /// Bandeau sombre en tête de document : logo + nom de la société à gauche,
  /// grand titre du document à droite, surmonté d'une fine barre dorée.
  static pw.Widget header({
    required Company? company,
    required Uint8List? logoBytes,
    required String documentTitle,
    required pw.Font boldFont,
    required pw.Font regularFont,
    List<pw.Widget> trailing = const [],
  }) {
    final address = company?.address.trim() ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: const pw.BoxDecoration(color: ink),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null) ...[
                pw.Container(
                  width: 50,
                  height: 50,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName(company),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                    if (address.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          address,
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 9,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    documentTitle,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 26,
                      color: gold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  ...trailing,
                ],
              ),
            ],
          ),
        ),
        pw.Container(width: double.infinity, height: 5, color: gold),
      ],
    );
  }

  /// Bandeau doré utilisé pour titrer une section (façon "DESCRIPTION OF WORK").
  static pw.Widget sectionBar(String label, {required pw.Font boldFont}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: gold,
      child: pw.Text(
        label,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 11,
          color: ink,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Pied de page sombre, 3 colonnes (téléphone / email / adresse), avec les
  /// mentions légales marocaines si renseignées (ICE, IF, RC, Patente).
  static pw.Widget footer({
    required Company? company,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final phone = company?.phone.trim() ?? '';
    final email = company?.email.trim() ?? '';
    final address = company?.address.trim() ?? '';
    final legal = _legalLine(company);

    pw.Widget column(String label, String value) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: gold,
                letterSpacing: 0.6,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value.isEmpty ? '-' : value,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 9,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(width: double.infinity, height: 3, color: gold),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          color: ink,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  column('TÉLÉPHONE', phone),
                  pw.SizedBox(width: 16),
                  column('EMAIL', email),
                  pw.SizedBox(width: 16),
                  column('ADRESSE', address),
                ],
              ),
              if (legal.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  legal,
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 7.5,
                    color: PdfColors.grey400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _legalLine(Company? company) {
    final parts = <String>[];
    final ice = company?.legalIce.trim() ?? '';
    final ifId = company?.legalIf.trim() ?? '';
    final rc = company?.legalRc.trim() ?? '';
    final patente = company?.legalPatente.trim() ?? '';
    if (ice.isNotEmpty) parts.add('ICE $ice');
    if (ifId.isNotEmpty) parts.add('IF $ifId');
    if (rc.isNotEmpty) parts.add('RC $rc');
    if (patente.isNotEmpty) parts.add('Patente $patente');
    return parts.join(' · ');
  }
}
