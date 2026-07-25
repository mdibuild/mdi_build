import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_build/core/enums/record_status.dart';
import 'package:mdi_build/core/enums/space_type.dart';
import 'package:mdi_build/core/models/opening_item.dart';
import 'package:mdi_build/core/models/space_item.dart';

SpaceItem _buildSpace({
  double length = 4,
  double width = 3,
  double height = 2.5,
  double quantity = 1,
  List<OpeningItem> openings = const [],
}) {
  return SpaceItem(
    id: 's1',
    companyId: 'c1',
    projectId: 'p1',
    type: SpaceType.piece,
    name: 'Salon',
    levelName: 'RDC',
    length: length,
    width: width,
    height: height,
    quantity: quantity,
    status: RecordStatus.brouillon,
    openings: openings,
  );
}

OpeningItem _buildOpening({
  double width = 1,
  double height = 2,
  double quantity = 1,
}) {
  return OpeningItem(
    id: 'o1',
    companyId: 'c1',
    projectId: 'p1',
    spaceId: 's1',
    name: 'Porte',
    openingType: 'porte',
    width: width,
    height: height,
    quantity: quantity,
  );
}

void main() {
  group('SpaceItem quantity calculations', () {
    test('floorArea is length * width * quantity', () {
      final space = _buildSpace(length: 4, width: 3, quantity: 2);
      expect(space.floorArea, 24);
    });

    test('ceilingArea equals floorArea', () {
      final space = _buildSpace(length: 5, width: 2);
      expect(space.ceilingArea, space.floorArea);
    });

    test('perimeter is 2 * (length + width) * quantity', () {
      final space = _buildSpace(length: 4, width: 3, quantity: 2);
      expect(space.perimeter, 28);
    });

    test('grossWallArea sums the four walls scaled by quantity', () {
      final space = _buildSpace(length: 4, width: 3, height: 2.5, quantity: 1);
      // (2*(4*2.5)) + (2*(3*2.5)) = 20 + 15 = 35
      expect(space.grossWallArea, 35);
    });

    test('openingsArea sums the area of every opening', () {
      final space = _buildSpace(
        openings: [
          _buildOpening(width: 1, height: 2), // 2
          _buildOpening(width: 0.8, height: 2, quantity: 2), // 3.2
        ],
      );
      expect(space.openingsArea, closeTo(5.2, 1e-9));
    });

    test('netWallArea subtracts openingsArea from grossWallArea', () {
      final space = _buildSpace(
        length: 4,
        width: 3,
        height: 2.5,
        openings: [_buildOpening(width: 1, height: 2)], // area 2
      );
      expect(space.netWallArea, space.grossWallArea - 2);
    });

    test('netWallArea never goes negative when openings exceed wall area',
        () {
      final space = _buildSpace(
        length: 1,
        width: 1,
        height: 1,
        openings: [_buildOpening(width: 10, height: 10)],
      );
      expect(space.netWallArea, 0);
    });
  });

  group('OpeningItem', () {
    test('area is width * height * quantity', () {
      final opening = _buildOpening(width: 1.2, height: 2, quantity: 3);
      expect(opening.area, closeTo(7.2, 1e-9));
    });
  });
}
