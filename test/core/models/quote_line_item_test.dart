import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_build/core/models/quote_line_item.dart';

void main() {
  group('QuoteLineItem', () {
    test('total is quantity * unitPrice', () {
      final item = QuoteLineItem(
        id: '1',
        quoteId: 'quote-1',
        label: 'Peinture murs',
        quantity: 12.5,
        unit: 'm2',
        unitPrice: 8,
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(item.total, 100);
    });

    test('total is zero when quantity is zero', () {
      final item = QuoteLineItem(
        id: '1',
        quoteId: 'quote-1',
        label: 'Peinture murs',
        quantity: 0,
        unit: 'm2',
        unitPrice: 8,
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(item.total, 0);
    });

    test('copyWith overrides only provided fields', () {
      final item = QuoteLineItem(
        id: '1',
        quoteId: 'quote-1',
        label: 'Peinture murs',
        quantity: 10,
        unit: 'm2',
        unitPrice: 5,
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final updated = item.copyWith(label: 'Peinture plafond', quantity: 20);

      expect(updated.label, 'Peinture plafond');
      expect(updated.quantity, 20);
      expect(updated.unitPrice, 5);
      expect(updated.id, '1');
    });
  });
}
