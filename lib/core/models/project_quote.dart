import 'package:equatable/equatable.dart';

class ProjectQuote extends Equatable {
  const ProjectQuote({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.mode,
    required this.status,
    required this.unitPriceWalls,
    required this.unitPriceCeiling,
    required this.signatureBase64,
    required this.sentAt,
    required this.signedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String mode;
  final String status;
  final double unitPriceWalls;
  final double unitPriceCeiling;
  final String? signatureBase64;
  final DateTime? sentAt;
  final DateTime? signedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectQuote.fromMap(Map<String, dynamic> map) {
    return ProjectQuote(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      mode: (map['mode'] as String?) ?? 'piece',
      status: (map['status'] as String?) ?? 'brouillon',
      unitPriceWalls: _toDouble(map['unit_price_walls']),
      unitPriceCeiling: _toDouble(map['unit_price_ceiling']),
      signatureBase64: map['signature_base64'] as String?,
      sentAt: map['sent_at'] == null
          ? null
          : DateTime.parse(map['sent_at'] as String),
      signedAt: map['signed_at'] == null
          ? null
          : DateTime.parse(map['signed_at'] as String),
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    final map = <String, dynamic>{
      'company_id': companyId,
      'project_id': projectId,
      'mode': mode,
      'status': status,
      'unit_price_walls': unitPriceWalls,
      'unit_price_ceiling': unitPriceCeiling,
      'signature_base64': signatureBase64,
      'sent_at': sentAt?.toIso8601String(),
      'signed_at': signedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  ProjectQuote copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? mode,
    String? status,
    double? unitPriceWalls,
    double? unitPriceCeiling,
    String? signatureBase64,
    bool clearSignature = false,
    DateTime? sentAt,
    bool clearSentAt = false,
    DateTime? signedAt,
    bool clearSignedAt = false,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectQuote(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      unitPriceWalls: unitPriceWalls ?? this.unitPriceWalls,
      unitPriceCeiling: unitPriceCeiling ?? this.unitPriceCeiling,
      signatureBase64:
          clearSignature ? null : signatureBase64 ?? this.signatureBase64,
      sentAt: clearSentAt ? null : sentAt ?? this.sentAt,
      signedAt: clearSignedAt ? null : signedAt ?? this.signedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
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
        projectId,
        mode,
        status,
        unitPriceWalls,
        unitPriceCeiling,
        signatureBase64,
        sentAt,
        signedAt,
        createdBy,
        updatedBy,
        createdAt,
        updatedAt,
      ];
}
