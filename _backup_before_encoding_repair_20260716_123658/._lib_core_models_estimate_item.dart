class EstimateItem {
  const EstimateItem({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  final String label;
  final double quantity;
  final String unit;
  final double unitPrice;

  double get total => quantity * unitPrice;
}
