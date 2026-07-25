import '../models/quantity_line.dart';
import '../models/space_item.dart';

class QuantityService {
  List<QuantityLine> buildLines(List<SpaceItem> spaces) {
    return spaces
        .map(
          (space) => QuantityLine(
            spaceId: space.id,
            spaceName: space.name,
            spaceType: space.type.label,
            floorArea: space.floorArea,
            ceilingArea: space.ceilingArea,
            grossWallArea: space.grossWallArea,
            openingsArea: space.openingsArea,
            netWallArea: space.netWallArea,
            perimeter: space.perimeter,
          ),
        )
        .toList();
  }
}
