/// Quantité importée (Excel) dans le Quantitatif d'un chantier.
class QuantityItem {
  const QuantityItem({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.label,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.total,
    this.sourceFile = '',
    this.sortOrder = 0,
    this.createdBy,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String label;
  final double quantity;
  final String unit;
  final double? unitPrice;
  final double? total;
  final String sourceFile;
  final int sortOrder;
  final String? createdBy;

  /// Prix unitaire connu, ou déduit du total.
  double? get effectiveUnitPrice {
    if (unitPrice != null) {
      return unitPrice;
    }
    if (total != null && quantity != 0) {
      return total! / quantity;
    }
    return null;
  }

  factory QuantityItem.fromMap(Map<String, dynamic> map) => QuantityItem(
        id: map['id'] as String,
        companyId: map['company_id'] as String,
        projectId: map['project_id'] as String,
        label: map['label'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unit: map['unit'] as String? ?? 'u',
        unitPrice: (map['unit_price'] as num?)?.toDouble(),
        total: (map['total'] as num?)?.toDouble(),
        sourceFile: map['source_file'] as String? ?? '',
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        createdBy: map['created_by']?.toString(),
      );

  Map<String, dynamic> toInsertMap() => {
        'company_id': companyId,
        'project_id': projectId,
        'label': label,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'total': total,
        'source_file': sourceFile,
        'sort_order': sortOrder,
        'created_by': createdBy,
      };
}
