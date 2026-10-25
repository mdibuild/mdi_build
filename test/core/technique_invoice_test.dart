import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/core/models/checklist_item.dart';
import 'package:mdi_build/core/models/project_invoice.dart';
import 'package:mdi_build/core/services/amount_in_words.dart';
import 'package:mdi_build/core/services/live_refresh.dart';
import 'package:mdi_build/core/utils/number_input.dart';
import 'package:mdi_build/features/technique/domain/concrete_mix.dart';
import 'package:mdi_build/features/technique/domain/rebar.dart';

void main() {
  group('Saisie des nombres', () {
    test('virgule, point, espaces, milliers', () {
      expect(parseDecimal('2,5'), 2.5);
      expect(parseDecimal('2.5'), 2.5);
      expect(parseDecimal('1 250,75'), 1250.75);
      expect(parseDecimal('1.250,75'), 1250.75);
      expect(parseDecimal('1,250.75'), 1250.75);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(formatDecimal(2), '2');
      expect(formatDecimal(2.5), '2,5');
      expect(formatDecimal(1.234), '1,234');
    });
  });

  group('Montant en lettres', () {
    test('règles françaises', () {
      expect(integerInWords(21), 'vingt et un');
      expect(integerInWords(71), 'soixante et onze');
      expect(integerInWords(80), 'quatre-vingts');
      expect(integerInWords(81), 'quatre-vingt-un');
      expect(integerInWords(97), 'quatre-vingt-dix-sept');
      expect(integerInWords(200), 'deux cents');
      expect(integerInWords(201), 'deux cent un');
      expect(integerInWords(1000), 'mille');
      expect(integerInWords(80000), 'quatre-vingt mille');
      expect(integerInWords(200000), 'deux cent mille');
      expect(integerInWords(2000000), 'deux millions');
      expect(integerInWords(1250080),
          'un million deux cent cinquante mille quatre-vingts');
    });

    test('dinars et centimes', () {
      expect(amountInWordsDzd(1), 'Un dinar algérien');
      expect(amountInWordsDzd(1309.5),
          'Mille trois cent neuf dinars algériens et cinquante centimes');
      expect(amountInWordsDzd(1000000), 'Un million de dinars algériens');
    });
  });

  group('Factures', () {
    test('totaux HT / TVA / TTC / reste et statut', () {
      final t = InvoiceTotals(const [
        InvoiceLineItem(
            label: 'Peinture', quantity: 10, unit: 'm²', unitPrice: 100),
        InvoiceLineItem(
            label: 'Enduit', quantity: 5, unit: 'm²', unitPrice: 20),
      ], 19, 500);
      expect(t.ht, 1100);
      expect(t.tax, closeTo(209, 1e-9));
      expect(t.ttc, closeTo(1309, 1e-9));
      expect(t.remaining, closeTo(809, 1e-9));
      expect(InvoiceTotals.statusFor('emise', 1309, 0), 'emise');
      expect(InvoiceTotals.statusFor('emise', 1309, 500), 'partielle');
      expect(InvoiceTotals.statusFor('emise', 1309, 1309), 'payee');
      expect(InvoiceTotals.statusFor('brouillon', 1309, 1309), 'brouillon');
    });

    test('numérotation annuelle', () {
      expect(nextInvoiceNumber(const [], 2026), 'FAC-2026-001');
      expect(
          nextInvoiceNumber(
              const ['FAC-2026-001', 'FAC-2026-009', 'FAC-2025-044'], 2026),
          'FAC-2026-010');
    });

    test('retard : échéance dépassée et reste à payer', () {
      ProjectInvoice invoice(String status, double paid) =>
          ProjectInvoice.fromMap({
            'id': 'f1',
            'company_id': 'c1',
            'project_id': 'p1',
            'number': 'FAC-2026-001',
            'status': status,
            'issue_date': '2026-09-01',
            'due_date': '2026-10-01',
            'tax_rate': 19,
            'amount_paid': paid,
            'created_at': '2026-09-01T10:00:00Z',
            'updated_at': '2026-09-01T10:00:00Z',
          });
      final today = DateTime(2026, 10, 25);
      expect(invoice('emise', 0).isOverdue(1000, today: today), isTrue);
      expect(invoice('payee', 1000).isOverdue(1000, today: today), isFalse);
      expect(invoice('emise', 1000).isOverdue(1000, today: today), isFalse);
      expect(invoice('emise', 0).isOverdue(1000, today: DateTime(2026, 10, 1)),
          isFalse);
    });
  });

  group('Béton', () {
    test('25 MPa : 350 kg/m³, 7 sacs de 50 kg par m³', () {
      final q = ConcreteQuantities(
        grade: gradeForMpa(25),
        volumeM3: 1,
        wastePercent: 0,
        bagKg: 50,
        wheelbarrowL: 60,
      );
      expect(q.cementKg, 350);
      expect(q.cementBagsRounded, 7);
      expect(q.sandM3, closeTo(0.4, 1e-9));
      expect(q.gravelM3, closeTo(0.8, 1e-9));
      expect(q.waterL, 175);
      expect(q.sandWheelbarrows, 7); // 400 L / 60 L
      expect(q.gravelWheelbarrows, 14); // 800 L / 60 L
      // Recette par sac : 1/7 des quantités.
      expect(q.sandPerBagL, closeTo(400 / 7, 1e-9));
      expect(q.waterPerBagL, closeTo(25, 1e-9));
    });

    test('pertes et interpolation entre deux classes', () {
      final q = ConcreteQuantities(
          grade: gradeForMpa(25), volumeM3: 2, wastePercent: 5);
      expect(q.orderedVolume, closeTo(2.1, 1e-9));
      expect(q.cementKg, closeTo(735, 1e-9));
      expect(q.cementBagsRounded, 15); // 14,7 sacs → 15
      final g = gradeForMpa(22.5);
      expect(g.cementKg, closeTo(325, 1e-9));
      expect(gradeForMpa(5).mpa, 10); // borné au tableau
      expect(gradeForMpa(60).mpa, 35);
    });

    test('volumes', () {
      expect(rectangularVolume(lengthM: 4, widthM: 3, thicknessM: 0.15),
          closeTo(1.8, 1e-9));
      expect(cylinderVolume(diameterM: 0.3, heightM: 3, count: 2),
          closeTo(0.424115, 1e-5));
    });
  });

  group('Ronds à béton', () {
    test('masses linéiques usuelles', () {
      expect(rebarKgPerMeter(8), closeTo(0.395, 0.001));
      expect(rebarKgPerMeter(10), closeTo(0.617, 0.001));
      expect(rebarKgPerMeter(12), closeTo(0.888, 0.001));
      expect(rebarKgPerMeter(16), closeTo(1.578, 0.001));
      // Règle de chantier d²/162 à moins de 0,2 % près.
      expect(rebarKgPerMeter(12), closeTo(144 / 162, 0.002));
    });

    test('conversions et nomenclature', () {
      expect(rebarWeightKg(diameterMm: 12, lengthM: 12), closeTo(10.65, 0.01));
      expect(rebarLengthM(diameterMm: 12, weightKg: 1000), closeTo(1126, 1));
      expect(barsForLength(24), 2);
      expect(barsForLength(24.1), 3);
      final summary = RebarSummary(const [
        RebarLine(diameterMm: 12, count: 10, lengthM: 6),
        RebarLine(diameterMm: 12, count: 4, lengthM: 3),
        RebarLine(diameterMm: 8, count: 20, lengthM: 1.2),
      ], wastePercent: 10);
      expect(summary.diameters, [8, 12]);
      expect(summary.lengthOf(12), closeTo(79.2, 1e-9));
      expect(summary.barsOf(12), 7);
      expect(summary.totalWeightKg,
          closeTo(summary.weightOf(8) + summary.weightOf(12), 1e-9));
    });
  });

  test('check-list : retard seulement si non faite et échéance passée', () {
    final item = ChecklistItem.fromMap({
      'id': 'k1',
      'company_id': 'c1',
      'title': 'Commander le ciment',
      'is_done': false,
      'due_date': '2026-10-20',
      'created_at': '2026-10-01T08:00:00Z',
    });
    expect(item.isOverdue(today: DateTime(2026, 10, 25)), isTrue);
    expect(item.isOverdue(today: DateTime(2026, 10, 20)), isFalse);
    expect(item.toInsertMap()['due_date'], '2026-10-20');
  });

  test('actualisation automatique : une rafale = une seule relecture',
      () async {
    var fired = 0;
    final debouncer = LiveRefreshDebouncer(() => fired++,
        delay: const Duration(milliseconds: 30));
    for (var i = 0; i < 5; i++) {
      debouncer.ping();
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, 1);
    debouncer.dispose();
  });
}
