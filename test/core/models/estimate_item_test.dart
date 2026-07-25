import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_build/core/models/estimate_item.dart';

void main() {
  group('EstimateItem', () {
    test('total is quantity * unitPrice', () {
      const item = EstimateItem(
        label: 'Peinture murs',
        quantity: 12.5,
        unit: 'm2',
        unitPrice: 8,
      );

      expect(item.total, 100);
    });

    test('total is zero when quantity is zero', () {
      const item = EstimateItem(
        label: 'Peinture murs',
        quantity: 0,
        unit: 'm2',
        unitPrice: 8,
      );

      expect(item.total, 0);
    });
  });
}
