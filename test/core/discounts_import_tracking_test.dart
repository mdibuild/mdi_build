import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/models/document_layout.dart';
import 'package:mdi_build/core/models/project_invoice.dart';
import 'package:mdi_build/core/models/project_quote.dart';
import 'package:mdi_build/core/models/purchase_workflow.dart';
import 'package:mdi_build/core/models/quote_line_item.dart';
import 'package:mdi_build/core/services/quantity_excel_import.dart';

void main() {
  group('Remises', () {
    test('remise de ligne puis remise globale, TVA sur le net', () {
      final t = DocumentTotals(const [
        PricedLine(quantity: 10, unitPrice: 100, discountPercent: 10), // 900
        PricedLine(quantity: 1, unitPrice: 100), // 100
      ], globalDiscountPercent: 5);
      expect(t.gross, 1100);
      expect(t.lineDiscounts, 100);
      expect(t.subtotal, 1000);
      expect(t.globalDiscount, 50);
      expect(t.netHt, 950);
      expect(t.tax, closeTo(180.5, 1e-9));
      expect(t.ttc, closeTo(1130.5, 1e-9));
      expect(t.totalDiscount, 150);
      expect(DocumentTotals(const [PricedLine(quantity: 1, unitPrice: 1)])
          .hasDiscount, isFalse);
      expect(clampPercent(150), 100);
      expect(clampPercent(-3), 0);
    });

    test('facture : totaux et reste à payer avec remises', () {
      final t = InvoiceTotals(const [
        InvoiceLineItem(
            label: 'A', quantity: 2, unit: 'u', unitPrice: 500,
            discountPercent: 50),
      ], 19, 100, globalDiscountPercent: 10);
      expect(t.ht, closeTo(450, 1e-9));
      expect(t.ttc, closeTo(535.5, 1e-9));
      expect(t.remaining, closeTo(435.5, 1e-9));
    });

    test('colonnes masquées : lecture et compatibilité base', () {
      expect(LineColumn.fromKeys(['unit_price', 'x']), {LineColumn.unitPrice});
      final quote = ProjectQuote.fromMap(const {
        'id': 'q1',
        'company_id': 'c1',
        'project_id': 'p1',
        'title': 'Devis',
        'mode': 'piece',
        'status': 'brouillon',
        'unit_price_walls': 0,
        'unit_price_ceiling': 0,
        'created_at': '2026-10-01T10:00:00',
        'updated_at': '2026-10-01T10:00:00',
      });
      // Base sans les colonnes v2.1 : rien n'est envoyé tant qu'aucune
      // remise ni colonne masquée n'est utilisée.
      expect(quote.toUpdateMap().containsKey('discount_percent'), isFalse);
      final withLayout = quote.copyWith(
          discountPercent: 5, hiddenColumns: ['unit_price']);
      expect(withLayout.toUpdateMap()['discount_percent'], 5);
      expect(withLayout.toUpdateMap()['hidden_columns'], ['unit_price']);
      final line = QuoteLineItem.fromMap({
        'id': 'l1',
        'quote_id': 'q1',
        'label': 'Peinture',
        'quantity': 10,
        'unit': 'm²',
        'unit_price': 100,
        'discount_percent': 20,
        'sort_order': 0,
        'created_at': '2026-10-01T10:00:00',
        'updated_at': '2026-10-01T10:00:00',
      });
      expect(line.total, 800);
      expect(line.toInsertMap()['discount_percent'], 20);
    });
  });

  group('Import Excel', () {
    test('en-tête reconnu, titres et sous-totaux ignorés', () {
      final r = parseQuantityRows([
        ['DQE — Villa Hydra'],
        [],
        ['N°', 'Désignation', 'Qté', 'Unité', 'P.U', 'Montant'],
        ['', 'GROS ŒUVRE'],
        ['1.1', 'Béton de propreté', 12.5, 'm³', 9000, 112500],
        ['1.2', 'Béton armé semelles', '18,4', 'm3', null, '552 000,00'],
        ['', 'Sous-total gros œuvre', null, null, null, 664500],
        ['2.1', 'Enduit', 300, 'm²'],
      ]);
      expect(r.headerFound, isTrue);
      expect(r.lines.length, 3);
      expect(r.skippedRows, 2);
      final b = r.lines[1];
      expect(b.label, 'Béton armé semelles');
      expect(b.quantity, 18.4);
      expect(b.total, 552000);
      expect(b.effectiveUnitPrice, closeTo(30000, 1e-6));
      expect(r.lines[0].total, 112500);
      expect(r.lines[2].total, isNull);
    });

    test('sans en-tête : colonnes A Désignation, B Qté, C Unité, D Total', () {
      final r = parseQuantityRows([
        ['Carrelage', 40, 'm²', 120000],
        ['Plinthes', 35, 'ml', 17500],
      ]);
      expect(r.headerFound, isFalse);
      expect(r.lines.map((l) => l.label), ['Carrelage', 'Plinthes']);
      expect(r.lines.first.effectiveUnitPrice, 3000);
    });

    test('vrai fichier .xlsx', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet()!];
      sheet.appendRow([
        TextCellValue('Désignation'),
        TextCellValue('Quantité'),
        TextCellValue('Unité'),
        TextCellValue('Total'),
      ]);
      sheet.appendRow([
        TextCellValue('Peinture murs'),
        const DoubleCellValue(85.5),
        TextCellValue('m²'),
        const IntCellValue(68400),
      ]);
      final bytes = Uint8List.fromList(excel.encode()!);
      final r = parseQuantityExcel(bytes);
      expect(r.lines.single.label, 'Peinture murs');
      expect(r.lines.single.quantity, 85.5);
      expect(r.lines.single.unit, 'm²');
      expect(r.lines.single.total, 68400);
    });
  });

  group('Suivi des achats', () {
    test('étapes et numéros de commande', () {
      expect(PurchaseWorkflow.label('brouillon'), 'Besoin émis');
      expect(PurchaseWorkflow.nextSteps('brouillon'),
          ['dg_valide', 'en_traitement']);
      expect(PurchaseWorkflow.nextSteps('en_traitement'), ['commande']);
      expect(PurchaseWorkflow.nextSteps('livre'), isEmpty);
      expect(PurchaseWorkflow.rank('commande'), 3);
      expect(PurchaseWorkflow.rank('annule'), -1);
      expect(nextOrderNumber(const [], 2026), 'BC-2026-001');
      expect(nextOrderNumber(const ['BC-2026-004', null, 'BC-2025-090'], 2026),
          'BC-2026-005');
    });

    test('évènement : titre lisible', () {
      final e = PurchaseEvent.fromMap({
        'id': 'e1',
        'purchase_id': 'a1',
        'kind': 'statut',
        'status': 'commande',
        'comment': 'Bon de commande BC-2026-001',
        'actor_name': 'Appro',
        'created_at': '2026-10-26T09:00:00Z',
      });
      expect(e.title, 'Commandé');
    });
  });
}
