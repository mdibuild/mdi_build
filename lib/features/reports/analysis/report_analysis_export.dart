import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/company.dart';
import '../../../core/services/pdf_letterhead.dart';
import 'report_analysis.dart';

/// Exports du rapport d'analyse. Ils sont construits à partir du MÊME objet
/// [AnalysisReport] que l'écran : mêmes filtres, toutes les lignes (pas
/// seulement celles visibles à l'écran), mêmes totaux.
class ReportAnalysisExport {
  String fileBaseName(AnalysisReport report) {
    final cleaned = report.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9À-ÿ._ -]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'rapport' : cleaned;
  }

  // -------------------------------------------------------------------------
  // PDF
  // -------------------------------------------------------------------------

  Future<void> printPdf(
    AnalysisReport report, {
    Company? company,
    Uint8List? logoBytes,
  }) async {
    final bytes = await buildPdf(report, company: company, logoBytes: logoBytes);
    await Printing.layoutPdf(
      name: '${fileBaseName(report)}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildPdf(
    AnalysisReport report, {
    Company? company,
    Uint8List? logoBytes,
    pw.Font? regular,
    pw.Font? bold,
  }) async {
    final regularFont = regular ?? await PdfGoogleFonts.notoSansRegular();
    final boldFont = bold ?? await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    pw.Widget pad(pw.Widget child, {double top = 10}) => pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(24, top, 24, 0),
          child: child,
        );

    const small = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
    final body = <pw.Widget>[
      PdfLetterhead.header(
        company: company,
        logoBytes: logoBytes,
        documentTitle: 'RAPPORT',
        boldFont: boldFont,
        regularFont: regularFont,
        outlined: true,
      ),
      pad(
        pw.Text(report.title,
            style: pw.TextStyle(font: boldFont, fontSize: 15)),
        top: 16,
      ),
      pad(pw.Text('Période : ${report.periodLabel}'), top: 4),
      if (report.activeFilters.isNotEmpty)
        pad(pw.Text('Filtres : ${report.activeFilters.join(' · ')}'), top: 2),
      pad(
        pw.Text(
          'Généré le ${formatDay(report.generatedAt)} — ${report.itemCount} '
          'élément(s) inclus',
          style: small,
        ),
        top: 2,
      ),
      pad(_indicatorsTable(report, boldFont)),
      for (final note in report.notes)
        pad(pw.Text('• $note', style: small), top: 3),
      for (final b in report.breakdowns)
        if (b.entries.isNotEmpty) ...[
          pad(pw.Text(b.title, style: pw.TextStyle(font: boldFont)), top: 12),
          pad(_breakdownTable(b, boldFont), top: 4),
        ],
      ..._detail(report, boldFont, small, pad),
      // Le cadre du pied de page porte sa propre marge (alignée sur l'en-tête).
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16),
        child: PdfLetterhead.footer(
          company: company,
          boldFont: boldFont,
          regularFont: regularFont,
          outlined: true,
        ),
      ),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(bottom: 20),
        build: (_) => body,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(right: 24),
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: small,
          ),
        ),
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _indicatorsTable(AnalysisReport report, pw.Font bold) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Indicateur', 'Valeur'],
      headerStyle: pw.TextStyle(font: bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: [
        for (final i in report.indicators)
          [i.label, i.hint == null ? i.value : '${i.value}  (${i.hint})'],
      ],
    );
  }

  pw.Widget _breakdownTable(ReportBreakdown b, pw.Font bold) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Catégorie',
        'Nombre',
        if (b.amountLabel != null) b.amountLabel!,
      ],
      headerStyle: pw.TextStyle(font: bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
      data: [
        for (final e in b.entries)
          [
            e.label,
            '${e.count}',
            if (b.amountLabel != null) e.amountText,
          ],
      ],
    );
  }

  List<pw.Widget> _detail(
    AnalysisReport report,
    pw.Font bold,
    pw.TextStyle small,
    pw.Widget Function(pw.Widget, {double top}) pad,
  ) {
    pw.Widget heading(String text) => pad(
          pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 12)),
          top: 16,
        );
    final tableHeader = pw.TextStyle(font: bold, fontSize: 8.5);
    const cell = pw.TextStyle(fontSize: 8.5);
    const headerBg = pw.BoxDecoration(color: PdfColors.grey200);

    switch (report.module) {
      case ReportModule.achats:
        final r = report.purchases!;
        return [
          heading('Détail des achats (${r.count})'),
          for (final row in r.rows) ...[
            pad(
              pw.Text(
                '${formatDay(row.day)} · ${row.purchase.title} · réf. interne '
                '${row.internalRef}',
                style: pw.TextStyle(font: bold, fontSize: 9.5),
              ),
              top: 10,
            ),
            pad(
              pw.Text(
                'Lot : ${row.purchase.lot.trim().isEmpty ? 'non renseigné' : row.purchase.lot} · '
                'Statut : ${purchaseStatusLabel(row.purchase.status)} · '
                'Commande : ${purchaseOrderedLabel(row.purchase)} · '
                'Livraison : ${purchaseDeliveredLabel(row.purchase)}',
                style: small,
              ),
              top: 2,
            ),
            if (row.items.isEmpty)
              pad(
                pw.Text('Aucune ligne d’article — montant non renseigné.',
                    style: small),
                top: 3,
              )
            else
              pad(
                pw.TableHelper.fromTextArray(
                  headers: const ['Article', 'Désignation', 'Qté', 'Unité', 'P.U.', 'Montant'],
                  headerStyle: tableHeader,
                  cellStyle: cell,
                  headerDecoration: headerBg,
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2),
                    1: pw.FlexColumnWidth(2.6),
                    2: pw.FlexColumnWidth(0.8),
                    3: pw.FlexColumnWidth(0.8),
                    4: pw.FlexColumnWidth(1.5),
                    5: pw.FlexColumnWidth(1.6),
                  },
                  cellAlignments: {
                    2: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                  },
                  data: [
                    for (final i in row.items)
                      [
                        i.article,
                        i.description,
                        formatQuantity(i.quantity),
                        i.unit,
                        i.unitPrice == 0
                            ? '0 (prix à 0)'
                            : formatAmount(i.unitPrice),
                        formatAmount(i.total),
                      ],
                    ['', '', '', '', 'Sous-total', formatAmount(row.amount!)],
                  ],
                ),
                top: 4,
              ),
          ],
          pad(
            pw.Text(
              'Total général connu : ${formatAmount(r.knownTotal)}'
              '${r.withoutAmount > 0 ? ' (hors ${r.withoutAmount} achat(s) sans montant)' : ''}',
              style: pw.TextStyle(font: bold, fontSize: 10.5),
            ),
            top: 12,
          ),
        ];

      case ReportModule.devis:
        final r = report.quotes!;
        return [
          heading('Détail des devis (${r.count})'),
          for (final row in r.rows) ...[
            pad(
              pw.Text(
                '${formatDay(row.day)} · ${row.quote.title} · '
                '${quoteStatusLabel(row.quote.status)}',
                style: pw.TextStyle(font: bold, fontSize: 9.5),
              ),
              top: 10,
            ),
            pad(
              pw.Text(
                'Client : ${row.clientName ?? 'non renseigné'} · '
                'HT : ${row.totalHt == null ? 'non renseigné' : formatAmount(row.totalHt!)} · '
                'TVA : ${row.tax == null ? 'non renseigné' : formatAmount(row.tax!)} · '
                'TTC : ${row.totalTtc == null ? 'non renseigné' : formatAmount(row.totalTtc!)}',
                style: small,
              ),
              top: 2,
            ),
            if (row.items.isNotEmpty)
              pad(
                pw.TableHelper.fromTextArray(
                  headers: const ['Prestation', 'Qté', 'Unité', 'P.U.', 'Montant HT'],
                  headerStyle: tableHeader,
                  cellStyle: cell,
                  headerDecoration: headerBg,
                  cellAlignments: {
                    1: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                  },
                  data: [
                    for (final i in row.items)
                      [
                        i.label,
                        formatQuantity(i.quantity),
                        i.unit,
                        formatAmount(i.unitPrice),
                        formatAmount(i.total),
                      ],
                  ],
                ),
                top: 4,
              ),
          ],
          pad(
            pw.Text(
              'Totaux connus : HT ${formatAmount(r.knownHt)} · TTC ${formatAmount(r.knownTtc)}',
              style: pw.TextStyle(font: bold, fontSize: 10.5),
            ),
            top: 12,
          ),
        ];

      case ReportModule.planning:
        final r = report.planning!;
        return [
          heading('Diagramme de Gantt (${r.rows.length} tâche(s) datée(s))'),
          if (r.rows.isNotEmpty) pad(_pdfGantt(r, report.period, small), top: 6),
          heading('Détail des tâches (${r.total})'),
          pad(
            pw.TableHelper.fromTextArray(
              headers: const ['Tâche', 'Phase', 'Responsable', 'Début', 'Fin', 'Durée', 'Avanc.', 'État'],
              headerStyle: tableHeader,
              cellStyle: cell,
              headerDecoration: headerBg,
              data: [
                for (final row in [...r.rows, ...r.undatedRows])
                  [
                    '${row.isMilestone ? '◆ ' : ''}${row.task.title}'
                        '${row.predecessors.isEmpty ? '' : '\n(après : ${row.predecessors.join(', ')})'}',
                    row.phaseTitle ?? '—',
                    row.assigneeName ?? 'non assigné',
                    row.task.plannedStartDate == null ? 'non renseigné' : formatDay(row.task.plannedStartDate!),
                    row.task.plannedEndDate == null ? 'non renseigné' : formatDay(row.task.plannedEndDate!),
                    row.durationDays == null ? '—' : '${row.durationDays} j',
                    '${row.task.progress.round()} %',
                    '${row.state.label}${row.finishedLate ? ' (fin tardive)' : ''}',
                  ],
              ],
            ),
            top: 4,
          ),
        ];

      case ReportModule.documents:
        final r = report.documents!;
        return [
          heading('Détail des documents (${r.count})'),
          pad(
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Titre', 'Catégorie', 'Fichier', 'Taille', 'Archivé'],
              headerStyle: tableHeader,
              cellStyle: cell,
              headerDecoration: headerBg,
              data: [
                for (final d in r.rows)
                  [
                    formatDay(documentDay(d)),
                    d.title,
                    documentCategoryLabel(d.category),
                    d.fileName,
                    formatBytes(d.fileSize),
                    d.isArchived ? 'Oui' : 'Non',
                  ],
              ],
            ),
            top: 4,
          ),
        ];

      case ReportModule.metrage:
        final r = report.metrage!;
        return [
          heading('Détail des espaces (${r.count})'),
          pad(
            pw.TableHelper.fromTextArray(
              headers: const ['Espace', 'Type', 'Sol m²', 'Plafond m²', 'Murs bruts m²', 'Ouvertures m²', 'Murs nets m²'],
              headerStyle: tableHeader,
              cellStyle: cell,
              headerDecoration: headerBg,
              data: [
                for (final l in r.lines)
                  [
                    l.spaceName,
                    l.spaceType,
                    formatQuantity(l.floorArea),
                    formatQuantity(l.ceilingArea),
                    formatQuantity(l.grossWallArea),
                    formatQuantity(l.openingsArea),
                    formatQuantity(l.netWallArea),
                  ],
                [
                  'Total',
                  '',
                  formatQuantity(r.floor),
                  formatQuantity(r.ceiling),
                  formatQuantity(r.grossWalls),
                  formatQuantity(r.openings),
                  formatQuantity(r.netWalls),
                ],
              ],
            ),
            top: 4,
          ),
        ];
    }
  }

  /// Gantt simplifié pour le PDF : une barre par tâche datée, proportionnelle
  /// à ses dates prévues sur l'étendue des tâches du rapport.
  pw.Widget _pdfGantt(PlanningReport r, ReportPeriod period, pw.TextStyle small) {
    DateTime start(TaskRow row) =>
        dateOnly(row.task.plannedStartDate ?? row.task.plannedEndDate!);
    DateTime end(TaskRow row) =>
        dateOnly(row.task.plannedEndDate ?? row.task.plannedStartDate!);
    var min = start(r.rows.first);
    var max = end(r.rows.first);
    for (final row in r.rows) {
      if (start(row).isBefore(min)) min = start(row);
      if (end(row).isAfter(max)) max = end(row);
    }
    final span = max.difference(min).inDays + 1;
    PdfColor color(TaskReportState s) {
      switch (s) {
        case TaskReportState.terminee:
          return PdfColors.green500;
        case TaskReportState.enRetard:
          return PdfColors.red500;
        case TaskReportState.enCours:
          return PdfColors.blue500;
        case TaskReportState.bloquee:
          return PdfColors.orange600;
        case TaskReportState.aVenir:
          return PdfColors.blueGrey400;
        case TaskReportState.annulee:
          return PdfColors.grey400;
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('Du ${formatDay(min)} au ${formatDay(max)} ($span jours)',
            style: small),
        pw.SizedBox(height: 4),
        for (final row in r.rows)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 150,
                  child: pw.Text(
                    row.task.title,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (start(row).difference(min).inDays > 0)
                        pw.Expanded(
                          flex: start(row).difference(min).inDays,
                          child: pw.SizedBox(),
                        ),
                      pw.Expanded(
                        flex: end(row).difference(start(row)).inDays + 1,
                        child: pw.Container(
                          height: 8,
                          color: color(row.state),
                        ),
                      ),
                      if (max.difference(end(row)).inDays > 0)
                        pw.Expanded(
                          flex: max.difference(end(row)).inDays,
                          child: pw.SizedBox(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Légende : vert terminée · bleu en cours · rouge en retard · orange '
          'bloquée · gris-bleu à faire · gris annulée',
          style: small,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Excel
  // -------------------------------------------------------------------------

  List<int> buildExcel(AnalysisReport report) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final summary = excel['Synthèse'];
    if (defaultSheet != null && defaultSheet != 'Synthèse') {
      excel.delete(defaultSheet);
    }

    CellValue t(String v) => TextCellValue(v);
    CellValue? n(double? v) => v == null ? null : DoubleCellValue(v);

    summary.appendRow([t(report.title)]);
    summary.appendRow([t('Période'), t(report.periodLabel)]);
    summary.appendRow([
      t('Filtres'),
      t(report.activeFilters.isEmpty ? 'Aucun' : report.activeFilters.join(' · ')),
    ]);
    summary.appendRow([t('Généré le'), t(formatDay(report.generatedAt))]);
    summary.appendRow([]);
    summary.appendRow([t('Indicateur'), t('Valeur'), t('Précision')]);
    for (final i in report.indicators) {
      summary.appendRow([t(i.label), t(i.value), t(i.hint ?? '')]);
    }
    summary.appendRow([]);
    for (final note in report.notes) {
      summary.appendRow([t('Note'), t(note)]);
    }
    for (final b in report.breakdowns) {
      summary.appendRow([]);
      summary.appendRow([
        t(b.title),
        t('Nombre'),
        if (b.amountLabel != null) ...[
          t('${b.amountLabel} (DA)'),
          t('Sans montant'),
        ],
      ]);
      for (final e in b.entries) {
        summary.appendRow([
          t(e.label),
          IntCellValue(e.count),
          if (b.amountLabel != null) ...[
            e.amountUnknown ? t('Non renseigné') : n(e.amount ?? 0),
            IntCellValue(e.missing),
          ],
        ]);
      }
    }

    final detail = excel['Détail'];
    switch (report.module) {
      case ReportModule.achats:
        detail.appendRow([
          t('Date'), t('Réf. interne'), t('Achat'), t('Lot'), t('Statut'),
          t('Date commande'), t('Date livraison'), t('Article'), t('Désignation'),
          t('Quantité'), t('Unité'), t('Prix unitaire (DA)'), t('Montant ligne (DA)'),
          t('Total achat (DA)'), t('Remarque'),
        ]);
        for (final row in report.purchases!.rows) {
          final p = row.purchase;
          final common = [
            t(formatDay(row.day)),
            t(row.internalRef),
            t(p.title),
            t(p.lot),
            t(purchaseStatusLabel(p.status)),
            t(purchaseOrderedLabel(p)),
            t(purchaseDeliveredLabel(p)),
          ];
          if (row.items.isEmpty) {
            detail.appendRow([
              ...common, null, null, null, null, null, null, null,
              t('Montant non renseigné (aucune ligne)'),
            ]);
          }
          for (final i in row.items) {
            detail.appendRow([
              ...common,
              t(i.article),
              t(i.description),
              n(i.quantity),
              t(i.unit),
              n(i.unitPrice),
              n(i.total),
              n(row.amount),
              t(i.unitPrice == 0 ? 'Prix à 0 (peut être non saisi)' : ''),
            ]);
          }
        }
      case ReportModule.devis:
        detail.appendRow([
          t('Date'), t('Devis'), t('Client'), t('Statut'), t('Prestation'),
          t('Quantité'), t('Unité'), t('Prix unitaire (DA)'), t('Montant HT ligne (DA)'),
          t('Total HT devis (DA)'), t('TVA (DA)'), t('Total TTC devis (DA)'),
        ]);
        for (final row in report.quotes!.rows) {
          final common = [
            t(formatDay(row.day)),
            t(row.quote.title),
            t(row.clientName ?? 'Non renseigné'),
            t(quoteStatusLabel(row.quote.status)),
          ];
          final totals = [n(row.totalHt), n(row.tax), n(row.totalTtc)];
          if (row.items.isEmpty) {
            detail.appendRow([...common, t('Montant non renseigné (aucune ligne)'), null, null, null, null, ...totals]);
          }
          for (final i in row.items) {
            detail.appendRow([
              ...common, t(i.label), n(i.quantity), t(i.unit), n(i.unitPrice), n(i.total), ...totals,
            ]);
          }
        }
      case ReportModule.planning:
        detail.appendRow([
          t('Tâche'), t('Type'), t('Phase'), t('Lot'), t('Responsable'), t('Début prévu'),
          t('Fin prévue'), t('Durée (jours)'), t('Début réel'), t('Fin réelle'),
          t('Avancement (%)'), t('Statut'), t('État dans le rapport'), t('Prédécesseurs'),
        ]);
        final r = report.planning!;
        for (final row in [...r.rows, ...r.undatedRows]) {
          final task = row.task;
          String d(DateTime? v) => v == null ? 'Non renseigné' : formatDay(v);
          detail.appendRow([
            t(task.title),
            t(row.isMilestone ? 'Jalon' : 'Tâche'),
            t(row.phaseTitle ?? ''),
            t(task.lot),
            t(row.assigneeName ?? 'Non assigné'),
            t(d(task.plannedStartDate)),
            t(d(task.plannedEndDate)),
            row.durationDays == null ? null : IntCellValue(row.durationDays!),
            t(d(task.actualStartDate)),
            t(d(task.actualEndDate)),
            n(task.progress),
            t(taskStatusLabel(task.status)),
            t('${row.state.label}${row.finishedLate ? ' (fin tardive)' : ''}'),
            t(row.predecessors.join(', ')),
          ]);
        }
      case ReportModule.documents:
        detail.appendRow([t('Date'), t('Titre'), t('Catégorie'), t('Fichier'), t('Taille (octets)'), t('Archivé')]);
        for (final doc in report.documents!.rows) {
          detail.appendRow([
            t(formatDay(documentDay(doc))),
            t(doc.title),
            t(documentCategoryLabel(doc.category)),
            t(doc.fileName),
            IntCellValue(doc.fileSize),
            t(doc.isArchived ? 'Oui' : 'Non'),
          ]);
        }
      case ReportModule.metrage:
        detail.appendRow([
          t('Espace'), t('Type'), t('Sol (m²)'), t('Plafond (m²)'), t('Murs bruts (m²)'),
          t('Ouvertures (m²)'), t('Murs nets (m²)'), t('Périmètre (m)'),
        ]);
        for (final l in report.metrage!.lines) {
          detail.appendRow([
            t(l.spaceName), t(l.spaceType), n(l.floorArea), n(l.ceilingArea),
            n(l.grossWallArea), n(l.openingsArea), n(l.netWallArea), n(l.perimeter),
          ]);
        }
    }

    return excel.save() ?? const <int>[];
  }

  /// Propose l'enregistrement du fichier Excel (« Enregistrer sous » sur
  /// ordinateur et téléphone, téléchargement sur le web).
  Future<String?> saveExcel(AnalysisReport report) {
    final bytes = Uint8List.fromList(buildExcel(report));
    return FilePicker.saveFile(
      dialogTitle: 'Enregistrer le rapport Excel',
      fileName: '${fileBaseName(report)}.xlsx',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: bytes,
    );
  }
}
