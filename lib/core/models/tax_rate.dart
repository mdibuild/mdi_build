import 'package:equatable/equatable.dart';

class TaxRate extends Equatable {
  const TaxRate({
    required this.id,
    required this.companyId,
    required this.label,
    required this.rate,
    required this.isDefault,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String label;
  final double rate;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaxRate.fromMap(Map<String, dynamic> map) {
    return TaxRate(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      label: (map['label'] as String?) ?? '',
      rate: _toDouble(map['rate']),
      isDefault: (map['is_default'] as bool?) ?? false,
      isArchived: (map['is_archived'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'label': label,
      'rate': rate,
      'is_default': isDefault,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'label': label,
      'rate': rate,
      'is_default': isDefault,
      'is_archived': isArchived,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TaxRate copyWith({
    String? id,
    String? companyId,
    String? label,
    double? rate,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxRate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      label: label ?? this.label,
      rate: rate ?? this.rate,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        label,
        rate,
        isDefault,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
