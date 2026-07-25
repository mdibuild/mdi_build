import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/project_report.dart';

class ReportPdfService {
  Future<Uint8List> buildReportPdf({
    required String projectName,
    required ProjectReport report,
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildHeader(
            projectName: projectName,
            report: report,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 16),
          _buildMeta(report),
          pw.SizedBox(height: 16),
          _buildSection(
            title: 'Avancement',
            value: report.progressSummary,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 12),
          _buildSection(
            title: 'Blocages',
            value: report.blockers,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 12),
          _buildSection(
            title: 'Décisions',
            value: report.decisions,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 12),
          _buildSection(
            title: 'Prochaines étapes',
            value: report.nextSteps,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printReport({
    required String projectName,
    required ProjectReport report,
  }) async {
    final bytes = await buildReportPdf(
      projectName: projectName,
      report: report,
    );

    await Printing.layoutPdf(
      name: 'rapport_${_safeFilePart(report.title)}.pdf',
      onLayout: (format) async => bytes,
    );
  }

  pw.Widget _buildHeader({
    required String projectName,
    required ProjectReport report,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RAPPORT DE CHANTIER',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 20,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            report.title,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 15,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Projet : $projectName',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Date du rapport : ${_formatDate(report.reportDate)}',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMeta(ProjectReport report) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Météo : ${_safeValue(report.weather)}'),
          pw.SizedBox(height: 4),
          pw.Text('Créé le : ${_formatDateTime(report.createdAt)}'),
          pw.SizedBox(height: 4),
          pw.Text('Mis à jour le : ${_formatDateTime(report.updatedAt)}'),
        ],
      ),
    );
  }

  pw.Widget _buildSection({
    required String title,
    required String value,
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
            title,
            style: pw.TextStyle(font: boldFont, fontSize: 12),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_safeValue(value)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'Rapport généré depuis le module Rapports.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  String _safeValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime value) {
    final date = _formatDate(value);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }

  String _safeFilePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'rapport' : cleaned;
  }
}
