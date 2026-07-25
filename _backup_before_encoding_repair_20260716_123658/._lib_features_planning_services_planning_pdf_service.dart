import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/project_task.dart';

class PlanningPdfService {
  Future<void> printPlanning({
    required String projectName,
    required List<ProjectTask> tasks,
  }) async {
    final pdf = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          _buildHeader(
            projectName: projectName,
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 16),
          _buildTasksTable(tasks),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _buildHeader({
    required String projectName,
    required String generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PLANNING PROJET',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  projectName,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'ÃƒÆ’Ã¢DAÂ°ditÃƒÆ’Ã‚Â© le : $generatedAt',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTasksTable(List<ProjectTask> tasks) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.4),
        5: const pw.FlexColumnWidth(1.1),
        6: const pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('TÃƒÆ’Ã‚Â¢che', bold: true),
            _cell('Type', bold: true),
            _cell('Statut', bold: true),
            _cell('PrioritÃƒÆ’Ã‚Â©', bold: true),
            _cell('Dates', bold: true),
            _cell('DurÃƒÆ’Ã‚Â©e', bold: true),
            _cell('Avancement', bold: true),
          ],
        ),
        ...tasks.map(
          (task) => pw.TableRow(
            children: [
              _cell('${task.title}\n${task.lot}'),
              _cell(task.isMilestone ? 'Jalon' : 'TÃƒÆ’Ã‚Â¢che'),
              _cell(_statusLabel(task.status)),
              _cell(_priorityLabel(task.priority)),
              _cell(_dateRange(task)),
              _cell('${task.plannedDurationDays} j'),
              _cell('${task.progress.toStringAsFixed(0)} %'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _dateRange(ProjectTask task) {
    final start = task.plannedStartDate == null
        ? '-'
        : DateFormat('dd/MM/yyyy').format(task.plannedStartDate!);
    final end = task.plannedEndDate == null
        ? '-'
        : DateFormat('dd/MM/yyyy').format(task.plannedEndDate!);
    return '$start\n$end';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'brouillon':
        return 'Brouillon';
      case 'a_faire':
        return 'ÃƒÆ’DA faire';
      case 'en_cours':
        return 'En cours';
      case 'bloquee':
        return 'BloquÃƒÆ’Ã‚Â©e';
      case 'terminee':
        return 'TerminÃƒÆ’Ã‚Â©e';
      case 'annulee':
        return 'AnnulÃƒÆ’Ã‚Â©e';
      case 'archivee':
        return 'ArchivÃƒÆ’Ã‚Â©e';
      default:
        return status;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'basse':
        return 'Basse';
      case 'normale':
        return 'Normale';
      case 'haute':
        return 'Haute';
      case 'urgente':
        return 'Urgente';
      default:
        return priority;
    }
  }
}
