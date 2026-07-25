class OpeningItem {
  const OpeningItem({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.spaceId,
    required this.name,
    required this.openingType,
    required this.width,
    required this.height,
    required this.quantity,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String spaceId;
  final String name;
  final String openingType;
  final double width;
  final double height;
  final double quantity;

  double get area => width * height * quantity;

  factory OpeningItem.fromMap(Map<String, dynamic> map) {
    return OpeningItem(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      spaceId: map['space_id'] as String,
      name: map['name'] as String? ?? '',
      openingType: map['opening_type'] as String? ?? '',
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'space_id': spaceId,
      'name': name,
      'opening_type': openingType,
      'width': width,
      'height': height,
      'quantity': quantity,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'opening_type': openingType,
      'width': width,
      'height': height,
      'quantity': quantity,
    };
  }
}
