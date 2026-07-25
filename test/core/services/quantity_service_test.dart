import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/space_type.dart';
import 'package:mdi_build/core/models/space_item.dart';
import 'package:mdi_build/core/services/quantity_service.dart';

SpaceItem _buildSpace({required String id, required String name}) {
  return SpaceItem(
    id: id,
    companyId: 'c1',
    projectId: 'p1',
    type: SpaceType.piece,
    name: name,
    levelName: 'RDC',
    length: 4,
    width: 3,
    height: 2.5,
    quantity: 1,
    status: RecordStatus.brouillon,
  );
}

void main() {
  group('QuantityService.buildLines', () {
    test('returns an empty list for no spaces', () {
      final lines = QuantityService().buildLines(const []);
      expect(lines, isEmpty);
    });

    test('maps each space to a quantity line preserving computed areas', () {
      final spaces = [
        _buildSpace(id: 's1', name: 'Salon'),
        _buildSpace(id: 's2', name: 'Cuisine'),
      ];

      final lines = QuantityService().buildLines(spaces);

      expect(lines, hasLength(2));
      expect(lines[0].spaceId, 's1');
      expect(lines[0].spaceName, 'Salon');
      expect(lines[0].floorArea, spaces[0].floorArea);
      expect(lines[0].ceilingArea, spaces[0].ceilingArea);
      expect(lines[0].grossWallArea, spaces[0].grossWallArea);
      expect(lines[0].netWallArea, spaces[0].netWallArea);
      expect(lines[1].spaceId, 's2');
      expect(lines[1].spaceName, 'Cuisine');
    });
  });
}
