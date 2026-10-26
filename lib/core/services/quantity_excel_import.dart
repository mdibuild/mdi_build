import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../utils/number_input.dart';

/// Ligne lue dans un fichier Excel de quantités.
class ImportedQuantityLine {
  const ImportedQuantityLine({
    required this.label,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.total,
  });

  final String label;
  final double quantity;
  final String unit;
  final double? unitPrice;
  final double? total;

  /// Prix unitaire connu ou déduit du total (total ÷ quantité).
  double? get effectiveUnitPrice {
    if (unitPrice != null) {
      return unitPrice;
    }
    if (total != null && quantity != 0) {
      return total! / quantity;
    }
    return null;
  }
}

class QuantityImportResult {
  const QuantityImportResult({
    required this.lines,
    required this.skippedRows,
    required this.headerFound,
    this.sheetName = '',
  });

  final List<ImportedQuantityLine> lines;

  /// Lignes ignorées : titres de chapitre, sous-totaux, lignes sans quantité.
  final int skippedRows;

  /// Une ligne d'en-tête (Désignation, Quantité…) a été reconnue ; sinon
  /// les colonnes A, B, C, D sont lues dans cet ordre.
  final bool headerFound;
  final String sheetName;
}

String _normalize(String s) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final lower = s.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(accents[ch] ?? ch);
  }
  return buffer.toString();
}

enum _Col { label, quantity, unit, unitPrice, total }

_Col? _columnFor(String header) {
  final h = _normalize(header).replaceAll(RegExp(r'[.\s_°]+'), ' ').trim();
  if (h.isEmpty) {
    return null;
  }
  if (h.contains('design') ||
      h.contains('libelle') ||
      h.contains('article') ||
      h.contains('description') ||
      h.contains('ouvrage') ||
      h.contains('intitule')) {
    return _Col.label;
  }
  if (h.contains('quantit') ||
      h == 'qte' ||
      h == 'qt' ||
      h == 'qty' ||
      h.startsWith('qte ')) {
    return _Col.quantity;
  }
  if (h.contains('unite') || h == 'unit' || h == 'u' || h == 'un') {
    return _Col.unit;
  }
  if (h.contains('prix unit') ||
      h == 'pu' ||
      h == 'p u' ||
      h.startsWith('pu ') ||
      h.contains('prix')) {
    return _Col.unitPrice;
  }
  if (h.contains('total') || h.contains('montant')) {
    return _Col.total;
  }
  return null;
}

double? _number(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final text = value.toString().replaceAll(RegExp(r'[A-Za-z€$]+'), '');
  return parseDecimal(text);
}

String _text(Object? value) => value == null ? '' : value.toString().trim();

/// Lecture de lignes déjà extraites d'une feuille (valeurs : texte ou
/// nombre). Séparée de la lecture du fichier pour être testée simplement.
QuantityImportResult parseQuantityRows(List<List<Object?>> rows,
    {String sheetName = ''}) {
  var mapping = <_Col, int>{};
  var start = 0;
  // En-tête cherché dans les 15 premières lignes.
  for (var r = 0; r < rows.length && r < 15; r++) {
    final found = <_Col, int>{};
    for (var c = 0; c < rows[r].length; c++) {
      final col = _columnFor(_text(rows[r][c]));
      if (col != null && !found.containsKey(col)) {
        found[col] = c;
      }
    }
    if (found.containsKey(_Col.label) &&
        (found.containsKey(_Col.quantity) || found.containsKey(_Col.total))) {
      mapping = found;
      start = r + 1;
      break;
    }
  }
  final headerFound = mapping.isNotEmpty;
  if (!headerFound) {
    mapping = {
      _Col.label: 0,
      _Col.quantity: 1,
      _Col.unit: 2,
      _Col.total: 3,
    };
  }

  Object? cell(List<Object?> row, _Col col) {
    final index = mapping[col];
    return index == null || index >= row.length ? null : row[index];
  }

  final lines = <ImportedQuantityLine>[];
  var skipped = 0;
  for (var r = start; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((v) => _text(v).isEmpty)) {
      continue; // ligne vide : ni importée ni comptée
    }
    final label = _text(cell(row, _Col.label));
    final quantity = _number(cell(row, _Col.quantity));
    final unitPrice = _number(cell(row, _Col.unitPrice));
    final total = _number(cell(row, _Col.total));
    final normalized = _normalize(label);
    final isSubtotal = normalized.startsWith('total') ||
        normalized.startsWith('sous-total') ||
        normalized.startsWith('sous total');
    if (label.isEmpty || isSubtotal || (quantity == null && total == null)) {
      skipped++;
      continue;
    }
    final unit = _text(cell(row, _Col.unit));
    final qty = quantity ?? 1;
    lines.add(ImportedQuantityLine(
      label: label,
      quantity: qty,
      unit: unit.isEmpty ? (quantity == null ? 'fft' : 'u') : unit,
      unitPrice: unitPrice,
      total: total ?? (unitPrice == null ? null : qty * unitPrice),
    ));
  }
  return QuantityImportResult(
    lines: lines,
    skippedRows: skipped,
    headerFound: headerFound,
    sheetName: sheetName,
  );
}

Object? _cellValue(Data? data) {
  final value = data?.value;
  return switch (value) {
    null => null,
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value,
    TextCellValue() => value.value.text,
    BoolCellValue(:final value) => value ? 'oui' : 'non',
    DateCellValue() => value.toString(),
    DateTimeCellValue() => value.toString(),
    TimeCellValue() => value.toString(),
    // Formule sans valeur calculée lisible : le total sera recalculé si
    // le prix unitaire est présent.
    FormulaCellValue() => null,
  };
}

/// Lit un fichier .xlsx : première feuille contenant des lignes chiffrées.
QuantityImportResult parseQuantityExcel(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  QuantityImportResult? best;
  for (final entry in excel.tables.entries) {
    final rows = [
      for (final row in entry.value.rows) [for (final c in row) _cellValue(c)],
    ];
    final result = parseQuantityRows(rows, sheetName: entry.key);
    if (best == null || result.lines.length > best.lines.length) {
      best = result;
    }
  }
  return best ??
      const QuantityImportResult(lines: [], skippedRows: 0, headerFound: false);
}
