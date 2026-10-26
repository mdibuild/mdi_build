import 'package:equatable/equatable.dart';

/// Valeur « inchangé » de copyWith pour les liens client/fournisseur
/// (permet aussi de les vider en passant null).
const Object _keepLink = Object();

class ProjectQuote extends Equatable {
  const ProjectQuote({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.title,
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
    this.clientId,
    this.discountPercent = 0,
    this.hiddenColumns = const [],
    this.layoutStored = false,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String title;
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

  /// Client destinataire du devis.
  final String? clientId;

  /// Remise globale en pourcentage, appliquée après les remises de ligne.
  final double discountPercent;

  /// Colonnes masquées sur le PDF (clés de [LineColumn]).
  final List<String> hiddenColumns;

  /// La base possède les colonnes de mise en page (v2.1).
  final bool layoutStored;

  Map<String, dynamic> _layoutMap() => {
        if (layoutStored || discountPercent != 0)
          'discount_percent': discountPercent,
        if (layoutStored || hiddenColumns.isNotEmpty)
          'hidden_columns': hiddenColumns,
      };

  factory ProjectQuote.fromMap(Map<String, dynamic> map) {
    return ProjectQuote(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      title: (map['title'] as String?) ?? 'Devis',
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
      clientId: map['client_id']?.toString(),
      discountPercent: _toDouble(map['discount_percent']),
      hiddenColumns: [
        for (final c in (map['hidden_columns'] as List<dynamic>?) ?? const [])
          c.toString(),
      ],
      layoutStored: map.containsKey('discount_percent'),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'project_id': projectId,
      'title': title,
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
      'client_id': clientId,
      ..._layoutMap(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'title': title,
      'mode': mode,
      'status': status,
      'unit_price_walls': unitPriceWalls,
      'unit_price_ceiling': unitPriceCeiling,
      'signature_base64': signatureBase64,
      'sent_at': sentAt?.toIso8601String(),
      'signed_at': signedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toIso8601String(),
      'client_id': clientId,
      ..._layoutMap(),
    };
  }

  ProjectQuote copyWith({
    Object? clientId = _keepLink,
    String? id,
    String? companyId,
    String? projectId,
    String? title,
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
    double? discountPercent,
    List<String>? hiddenColumns,
  }) {
    return ProjectQuote(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
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
      clientId:
          identical(clientId, _keepLink) ? this.clientId : clientId as String?,
      discountPercent: discountPercent ?? this.discountPercent,
      hiddenColumns: hiddenColumns ?? this.hiddenColumns,
      layoutStored: layoutStored,
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
        discountPercent,
        hiddenColumns,
        clientId,
        id,
        companyId,
        projectId,
        title,
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
