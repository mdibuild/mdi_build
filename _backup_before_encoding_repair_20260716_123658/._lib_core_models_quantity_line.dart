class QuantityLine {
  const QuantityLine({
    required this.spaceId,
    required this.spaceName,
    required this.spaceType,
    required this.floorArea,
    required this.ceilingArea,
    required this.grossWallArea,
    required this.openingsArea,
    required this.netWallArea,
    required this.perimeter,
  });

  final String spaceId;
  final String spaceName;
  final String spaceType;
  final double floorArea;
  final double ceilingArea;
  final double grossWallArea;
  final double openingsArea;
  final double netWallArea;
  final double perimeter;
}
