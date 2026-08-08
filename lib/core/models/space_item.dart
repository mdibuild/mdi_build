import '../enums/record_status.dart';
import '../enums/space_type.dart';
import 'opening_item.dart';

class SpaceItem {
  const SpaceItem({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.type,
    required this.name,
    required this.levelName,
    required this.length,
    required this.width,
    required this.height,
    required this.quantity,
    required this.status,
    this.openings = const [],
  });

  final String id;
  final String companyId;
  final String projectId;
  final SpaceType type;
  final String name;
  final String levelName;
  final double length;
  final double width;
  final double height;
  final double quantity;
  final RecordStatus status;
  final List<OpeningItem> openings;

  double get floorArea => length * width * quantity;
  double get ceilingArea => floorArea;
  double get perimeter => 2 * (length + width) * quantity;
  double get grossWallArea =>
      ((2 * (length * height)) + (2 * (width * height))) * quantity;
  double get openingsArea => openings.fold(0, (sum, item) => sum + item.area);
  double get netWallArea =>
      grossWallArea - openingsArea < 0 ? 0 : grossWallArea - openingsArea;

  factory SpaceItem.fromMap(Map<String, dynamic> map,
      {List<OpeningItem> openings = const []}) {
    return SpaceItem(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      type: SpaceType.fromDb(map['type'] as String? ?? 'piece'),
      name: map['name'] as String? ?? '',
      levelName: map['level_name'] as String? ?? '',
      length: (map['length'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      status: RecordStatus.fromDb(map['status'] as String? ?? 'brouillon'),
      openings: openings,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'type': type.dbValue,
      'name': name,
      'level_name': levelName,
      'length': length,
      'width': width,
      'height': height,
      'quantity': quantity,
      'status': status.dbValue,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'type': type.dbValue,
      'name': name,
      'level_name': levelName,
      'length': length,
      'width': width,
      'height': height,
      'quantity': quantity,
      'status': status.dbValue,
    };
  }

  SpaceItem copyWith({
    String? id,
    String? companyId,
    String? projectId,
    SpaceType? type,
    String? name,
    String? levelName,
    double? length,
    double? width,
    double? height,
    double? quantity,
    RecordStatus? status,
    List<OpeningItem>? openings,
  }) {
    return SpaceItem(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      type: type ?? this.type,
      name: name ?? this.name,
      levelName: levelName ?? this.levelName,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      openings: openings ?? this.openings,
    );
  }
}
