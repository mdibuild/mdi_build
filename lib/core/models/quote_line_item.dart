class QuoteLineItem {
  const QuoteLineItem({
    required this.id,
    required this.quoteId,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String quoteId;
  final String label;
  final double quantity;
  final String unit;
  final double unitPrice;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get total => quantity * unitPrice;

  factory QuoteLineItem.fromMap(Map<String, dynamic> map) {
    return QuoteLineItem(
      id: map['id'] as String,
      quoteId: map['quote_id'] as String,
      label: map['label'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'u',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'quote_id': quoteId,
      'label': label,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'label': label,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'sort_order': sortOrder,
    };
  }

  QuoteLineItem copyWith({
    String? id,
    String? quoteId,
    String? label,
    double? quantity,
    String? unit,
    double? unitPrice,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuoteLineItem(
      id: id ?? this.id,
      quoteId: quoteId ?? this.quoteId,
      label: label ?? this.label,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
