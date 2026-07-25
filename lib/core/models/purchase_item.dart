class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.article,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.notes,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String purchaseId;
  final String article;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get total => quantity * unitPrice;

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      article: map['article'] as String? ?? '',
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'u',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'purchase_id': purchaseId,
      'article': article,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'notes': notes,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'article': article,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'notes': notes,
      'sort_order': sortOrder,
    };
  }

  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? article,
    String? description,
    double? quantity,
    String? unit,
    double? unitPrice,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      article: article ?? this.article,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
