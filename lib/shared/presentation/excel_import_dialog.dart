import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/quantity_excel_import.dart';
import '../../core/utils/number_input.dart';

/// Lignes importées et nom du fichier d'origine.
class ExcelImportSelection {
  const ExcelImportSelection(this.lines, this.fileName);

  final List<ImportedQuantityLine> lines;
  final String fileName;
}

/// Choisit un fichier Excel (.xlsx), montre un aperçu des lignes reconnues
/// (Désignation, Quantité, Unité, PU, Total) et renvoie celles à importer.
Future<ExcelImportSelection?> pickQuantitiesFromExcel(
    BuildContext context) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  final file = picked?.files.singleOrNull;
  if (file == null) {
    return null;
  }
  final bytes = file.bytes;
  if (bytes == null) {
    if (context.mounted) {
      _snack(context, 'Impossible de lire le fichier.');
    }
    return null;
  }
  final QuantityImportResult result;
  try {
    result = parseQuantityExcel(bytes);
  } catch (error) {
    if (context.mounted) {
      _snack(context,
          'Fichier illisible. Enregistre-le au format Excel .xlsx puis réessaie.');
    }
    return null;
  }
  if (!context.mounted) {
    return null;
  }
  if (result.lines.isEmpty) {
    _snack(
      context,
      'Aucune ligne chiffrée trouvée. Le tableau doit contenir une colonne '
      'Désignation et une colonne Quantité (ou Total).',
    );
    return null;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _PreviewDialog(
      result: result,
      fileName: file.name,
    ),
  );
  return confirmed == true
      ? ExcelImportSelection(result.lines, file.name)
      : null;
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({required this.result, required this.fileName});

  final QuantityImportResult result;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final preview = result.lines.take(12).toList();
    String n(double? v) => v == null ? '—' : formatDecimal(v, maxDecimals: 2);
    return AlertDialog(
      title: Text('Importer ${result.lines.length} ligne(s)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$fileName${result.sheetName.isEmpty ? '' : ' · feuille « ${result.sheetName} »'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                result.headerFound
                    ? 'En-tête reconnu.'
                    : 'Pas d’en-tête reconnu : colonnes lues dans l’ordre '
                        'A Désignation, B Quantité, C Unité, D Total.',
              ),
              if (result.skippedRows > 0)
                Text('${result.skippedRows} ligne(s) ignorée(s) (titres, '
                    'sous-totaux ou sans quantité).'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 30,
                  dataRowMaxHeight: 36,
                  columns: const [
                    DataColumn(label: Text('Désignation')),
                    DataColumn(label: Text('Qté'), numeric: true),
                    DataColumn(label: Text('Unité')),
                    DataColumn(label: Text('PU'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: [
                    for (final l in preview)
                      DataRow(cells: [
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(l.label, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(n(l.quantity))),
                        DataCell(Text(l.unit)),
                        DataCell(Text(n(l.unitPrice))),
                        DataCell(Text(n(l.total))),
                      ]),
                  ],
                ),
              ),
              if (result.lines.length > preview.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '… et ${result.lines.length - preview.length} autre(s).'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.file_download_done_outlined),
          label: const Text('Importer'),
        ),
      ],
    );
  }
}
