import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('excel package still produces a valid, round-trippable .xlsx with xml 7 override', () {
    final excel = Excel.createExcel();

    final sheet = excel['Sections'];
    sheet.appendRow([
      TextCellValue('Ordre'),
      TextCellValue('Titre'),
      TextCellValue('Auto'),
    ]);
    sheet.appendRow([
      const IntCellValue(1),
      TextCellValue('Résumé du chantier'),
      TextCellValue('Oui'),
    ]);

    try {
      excel.delete('Sheet1');
    } catch (_) {}

    final bytes = excel.save();
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(0));

    final reloaded = Excel.decodeBytes(bytes);
    final reloadedSheet = reloaded['Sections'];

    expect(reloadedSheet.maxRows, 2);
    expect(reloadedSheet.rows[0][0]?.value, TextCellValue('Ordre'));
    expect(
      reloadedSheet.rows[1][1]?.value,
      TextCellValue('Résumé du chantier'),
    );
  });
}
