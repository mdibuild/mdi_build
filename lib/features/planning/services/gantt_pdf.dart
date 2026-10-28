import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../presentation/gantt_view.dart' show GanttScale;

/// État d'une barre du Gantt imprimé (couleur).
enum GanttBarState { done, late, inProgress, blocked, todo, cancelled }

/// Une ligne du Gantt imprimé.
class GanttPdfRow {
  const GanttPdfRow({
    required this.title,
    required this.start,
    required this.end,
    this.progress = 0,
    this.state = GanttBarState.todo,
    this.milestone = false,
    this.assignee,
    this.phase,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  /// Avancement 0 à 100.
  final double progress;
  final GanttBarState state;
  final bool milestone;
  final String? assignee;
  final String? phase;
}

/// Colonne de l'axe du temps : [start] inclus, [end] exclu.
class GanttColumn {
  const GanttColumn(this.start, this.end, this.label, {this.subLabel = ''});

  final DateTime start;
  final DateTime end;
  final String label;
  final String subLabel;

  int get days => end.difference(start).inDays;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Colonnes couvrant [from]..[to] (inclus) à l'échelle [scale].
List<GanttColumn> ganttColumns(DateTime from, DateTime to, GanttScale scale) {
  final first = _day(from);
  final last = _day(to);
  final columns = <GanttColumn>[];
  // Noms français écrits en dur : pas de dépendance aux données de locale
  // (indisponibles hors de l'interface, par exemple pendant un export).
  const weekdays = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
  const months = [
    'janv',
    'févr',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sept',
    'oct',
    'nov',
    'déc',
  ];
  String two(int v) => v.toString().padLeft(2, '0');
  String dayLabel(DateTime d) => '${two(d.day)}/${two(d.month)}';
  String monthLabel(DateTime d) =>
      '${months[d.month - 1]} ${two(d.year % 100)}';

  int monthsPer(GanttScale s) => switch (s) {
        GanttScale.month => 1,
        GanttScale.bimester => 2,
        GanttScale.quarter => 3,
        GanttScale.semester => 6,
        GanttScale.year => 12,
        _ => 1,
      };

  switch (scale) {
    case GanttScale.day:
      for (var d = first;
          !d.isAfter(last);
          d = DateTime(d.year, d.month, d.day + 1)) {
        columns.add(GanttColumn(
            d, DateTime(d.year, d.month, d.day + 1), dayLabel(d),
            subLabel: weekdays[d.weekday - 1]));
      }
    case GanttScale.week:
      var d =
          DateTime(first.year, first.month, first.day - (first.weekday - 1));
      while (!d.isAfter(last)) {
        final next = DateTime(d.year, d.month, d.day + 7);
        columns.add(
            GanttColumn(d, next, 'S${_isoWeek(d)}', subLabel: dayLabel(d)));
        d = next;
      }
    default:
      final step = monthsPer(scale);
      var m = DateTime(first.year, ((first.month - 1) ~/ step) * step + 1);
      while (!m.isAfter(last)) {
        final next = DateTime(m.year, m.month + step);
        final label = switch (scale) {
          GanttScale.month => monthLabel(m),
          GanttScale.bimester => 'B${(m.month - 1) ~/ 2 + 1} ${m.year}',
          GanttScale.quarter => 'T${(m.month - 1) ~/ 3 + 1} ${m.year}',
          GanttScale.semester => 'S${(m.month - 1) ~/ 6 + 1} ${m.year}',
          _ => '${m.year}',
        };
        columns.add(GanttColumn(m, next, label,
            subLabel: scale == GanttScale.month ? '' : monthLabel(m)));
        m = next;
      }
  }
  return columns;
}

int _isoWeek(DateTime d) {
  final thursday = DateTime(d.year, d.month, d.day + (4 - d.weekday));
  final firstJan = DateTime(thursday.year, 1, 1);
  return thursday.difference(firstJan).inDays ~/ 7 + 1;
}

/// Largeur d'une colonne (points PDF) selon l'échelle.
double ganttUnitWidth(GanttScale scale) => switch (scale) {
      GanttScale.day => 24,
      GanttScale.week => 42,
      GanttScale.month => 54,
      GanttScale.bimester => 60,
      GanttScale.quarter => 64,
      GanttScale.semester => 72,
      GanttScale.year => 84,
    };

/// Mise en page A4 paysage.
class GanttPdfLayout {
  GanttPdfLayout({
    required this.rows,
    required this.scale,
    this.labelWidth = 200,
    this.rowHeight = 18,
  }) {
    var min = _day(rows.first.start);
    var max = _day(rows.first.end);
    for (final r in rows) {
      if (_day(r.start).isBefore(min)) min = _day(r.start);
      if (_day(r.end).isAfter(max)) max = _day(r.end);
    }
    from = min;
    to = max;
    columns = ganttColumns(min, max, scale);
  }

  static final format = PdfPageFormat.a4.landscape;
  static const margin = 22.0;

  final List<GanttPdfRow> rows;
  final GanttScale scale;
  final double labelWidth;
  final double rowHeight;
  late final DateTime from;
  late final DateTime to;
  late final List<GanttColumn> columns;

  double get unitWidth => ganttUnitWidth(scale);
  double get timelineWidth => format.width - 2 * margin - labelWidth;

  int get columnsPerPage => math.max(1, (timelineWidth / unitWidth).floor());

  /// En-tête (titre + axe) et pied réservés sur chaque planche.
  int get rowsPerPage {
    const reserved = 26 + 34 + 30; // titre, axe du temps, pied + légende
    final usable = format.height - 2 * margin - reserved;
    return math.max(1, (usable / rowHeight).floor());
  }

  int get horizontalSheets => (columns.length / columnsPerPage).ceil();
  int get verticalSheets => (rows.length / rowsPerPage).ceil();
  int get sheets => horizontalSheets * verticalSheets;
}

/// Échelle la plus fine qui tient sur au plus [maxWide] planches en largeur.
GanttScale autoGanttScale(List<GanttPdfRow> rows, {int maxWide = 2}) {
  for (final scale in GanttScale.values) {
    if (GanttPdfLayout(rows: rows, scale: scale).horizontalSheets <= maxWide) {
      return scale;
    }
  }
  return GanttScale.year;
}

PdfColor _barColor(GanttBarState s) => switch (s) {
      GanttBarState.done => PdfColors.green500,
      GanttBarState.late => PdfColors.red500,
      GanttBarState.inProgress => PdfColors.blue500,
      GanttBarState.blocked => PdfColors.orange600,
      GanttBarState.todo => PdfColors.blueGrey400,
      GanttBarState.cancelled => PdfColors.grey400,
    };

const _ink = PdfColor.fromInt(0xFF0B2436);
const _gold = PdfColor.fromInt(0xFFE7B800);

/// Planches du Gantt complet (A4 paysage), dans l'ordre de lecture : par
/// période (gauche → droite) puis par groupe de tâches (haut → bas).
List<pw.Page> ganttPdfPages({
  required List<GanttPdfRow> rows,
  required GanttScale scale,
  required String title,
  String subtitle = '',
  String companyName = '',
  DateTime? today,
  required pw.Font regular,
  required pw.Font bold,
}) {
  if (rows.isEmpty) {
    return const [];
  }
  final layout = GanttPdfLayout(rows: rows, scale: scale);
  final now = _day(today ?? DateTime.now());
  final day = DateFormat('dd/MM/yyyy');
  final pages = <pw.Page>[];
  var sheet = 0;

  for (var h = 0; h < layout.horizontalSheets; h++) {
    final cols = layout.columns
        .skip(h * layout.columnsPerPage)
        .take(layout.columnsPerPage)
        .toList();
    final windowStart = cols.first.start;
    final windowEnd = cols.last.end; // exclu
    final unit = layout.unitWidth;
    final width = cols.length * unit;

    // Position x d'une date dans la fenêtre (bornée).
    double x(DateTime d) {
      final day = _day(d);
      if (!day.isAfter(windowStart)) return 0;
      if (!day.isBefore(windowEnd)) return width;
      for (var i = 0; i < cols.length; i++) {
        final c = cols[i];
        if (day.isBefore(c.end)) {
          return i * unit + unit * day.difference(c.start).inDays / c.days;
        }
      }
      return width;
    }

    for (var v = 0; v < layout.verticalSheets; v++) {
      sheet++;
      final slice =
          rows.skip(v * layout.rowsPerPage).take(layout.rowsPerPage).toList();
      final sheetNumber = sheet;
      pages.add(pw.Page(
        pageFormat: GanttPdfLayout.format,
        margin: const pw.EdgeInsets.all(GanttPdfLayout.margin),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Titre de la planche
            pw.Container(
              height: 26,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: _gold, width: 2)),
              ),
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(
                    '$title${subtitle.isEmpty ? '' : ' — $subtitle'}',
                    maxLines: 1,
                    style: pw.TextStyle(font: bold, fontSize: 11, color: _ink),
                  ),
                ),
                pw.Text(
                  'Planche $sheetNumber / ${layout.sheets} · ${scale.label} · '
                  '${day.format(windowStart)} → '
                  '${day.format(windowEnd.subtract(const Duration(days: 1)))}',
                  style: pw.TextStyle(font: regular, fontSize: 8.5),
                ),
              ]),
            ),
            // Axe du temps
            pw.Row(children: [
              pw.Container(
                width: layout.labelWidth,
                height: 34,
                alignment: pw.Alignment.bottomLeft,
                padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
                child: pw.Text(
                  'Tâches ${v * layout.rowsPerPage + 1}–'
                  '${v * layout.rowsPerPage + slice.length} sur ${rows.length}',
                  style: pw.TextStyle(font: bold, fontSize: 8),
                ),
              ),
              for (final c in cols)
                pw.Container(
                  width: unit,
                  height: 34,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                      bottom:
                          pw.BorderSide(color: PdfColors.grey500, width: 0.8),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(c.label,
                          style: pw.TextStyle(font: bold, fontSize: 7.5)),
                      if (c.subLabel.isNotEmpty)
                        pw.Text(c.subLabel,
                            style: pw.TextStyle(font: regular, fontSize: 6.5)),
                    ],
                  ),
                ),
            ]),
            // Lignes
            for (var i = 0; i < slice.length; i++)
              _row(slice[i], i, layout, cols, unit, width, x, now, regular,
                  bold),
            pw.Spacer(),
            pw.Row(children: [
              for (final s in GanttBarState.values) ...[
                pw.Container(width: 10, height: 6, color: _barColor(s)),
                pw.SizedBox(width: 3),
                pw.Text(
                  switch (s) {
                    GanttBarState.done => 'Terminée',
                    GanttBarState.late => 'En retard',
                    GanttBarState.inProgress => 'En cours',
                    GanttBarState.blocked => 'Bloquée',
                    GanttBarState.todo => 'À faire',
                    GanttBarState.cancelled => 'Annulée',
                  },
                  style: pw.TextStyle(font: regular, fontSize: 7),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Container(width: 1.5, height: 8, color: PdfColors.red700),
              pw.SizedBox(width: 3),
              pw.Text("Aujourd'hui",
                  style: pw.TextStyle(font: regular, fontSize: 7)),
              pw.Spacer(),
              if (companyName.isNotEmpty)
                pw.Text(companyName,
                    style: pw.TextStyle(font: bold, fontSize: 7, color: _ink)),
            ]),
          ],
        ),
      ));
    }
  }
  return pages;
}

pw.Widget _row(
  GanttPdfRow r,
  int index,
  GanttPdfLayout layout,
  List<GanttColumn> cols,
  double unit,
  double width,
  double Function(DateTime) x,
  DateTime today,
  pw.Font regular,
  pw.Font bold,
) {
  final h = layout.rowHeight;
  final start = x(r.start);
  // Barre jusqu'à la fin du dernier jour (fin incluse).
  final end = x(DateTime(r.end.year, r.end.month, r.end.day + 1));
  final visible = end > start || r.milestone;
  final barWidth = math.max(2.0, end - start);
  final todayX = x(today);
  final showToday = todayX > 0 && todayX < width;
  final color = _barColor(r.state);
  final label = [
    if (r.phase != null && r.phase!.isNotEmpty) r.phase!,
    if (r.assignee != null && r.assignee!.isNotEmpty) r.assignee!,
  ].join(' · ');

  return pw.Container(
    height: h,
    decoration: pw.BoxDecoration(
      color:
          index.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF5F7F9),
      border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
    ),
    child: pw.Row(children: [
      pw.Container(
        width: layout.labelWidth,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${r.milestone ? 'Jalon · ' : ''}${r.title}',
                maxLines: 1, style: pw.TextStyle(font: bold, fontSize: 7.2)),
            if (label.isNotEmpty)
              pw.Text(label,
                  maxLines: 1,
                  style: pw.TextStyle(
                      font: regular, fontSize: 5.8, color: PdfColors.grey700)),
          ],
        ),
      ),
      pw.SizedBox(
        width: width,
        height: h,
        child: pw.Stack(children: [
          // Quadrillage des colonnes
          pw.Row(children: [
            for (final _ in cols)
              pw.Container(
                width: unit,
                height: h,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      left:
                          pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
                ),
              ),
          ]),
          if (visible && !r.milestone)
            pw.Positioned(
              left: start,
              top: h * 0.25,
              child: pw.Stack(children: [
                pw.Container(width: barWidth, height: h * 0.5, color: color),
                pw.Container(
                  width: barWidth * (r.progress.clamp(0, 100) / 100),
                  height: h * 0.5,
                  color: PdfColor(
                      color.red * 0.6, color.green * 0.6, color.blue * 0.6),
                ),
              ]),
            ),
          if (visible && r.milestone)
            pw.Positioned(
              left: math.max(0, start - 4),
              top: h / 2 - 4,
              child: pw.Transform.rotate(
                angle: math.pi / 4,
                child: pw.Container(width: 7, height: 7, color: _ink),
              ),
            ),
          if (showToday)
            pw.Positioned(
              left: todayX,
              top: 0,
              child: pw.Container(width: 1, height: h, color: PdfColors.red700),
            ),
        ]),
      ),
    ]),
  );
}

/// Gantt complet seul (sans le reste du rapport).
Future<Uint8List> buildGanttPdf({
  required List<GanttPdfRow> rows,
  required GanttScale scale,
  required String title,
  String subtitle = '',
  String companyName = '',
  pw.Font? regular,
  pw.Font? bold,
}) async {
  final r = regular ?? await PdfGoogleFonts.notoSansRegular();
  final b = bold ?? await PdfGoogleFonts.notoSansBold();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: r, bold: b));
  for (final page in ganttPdfPages(
    rows: rows,
    scale: scale,
    title: title,
    subtitle: subtitle,
    companyName: companyName,
    regular: r,
    bold: b,
  )) {
    doc.addPage(page);
  }
  return Uint8List.fromList(await doc.save());
}
