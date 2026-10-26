class EstimateItem {
  const EstimateItem({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  final String label;
  final double quantity;
  final String unit;
  final double unitPrice;

  /// Remise de la ligne en pourcentage (0 à 100).
  final double discountPercent;

  double get grossTotal => quantity * unitPrice;
  double get total => grossTotal * (1 - discountPercent / 100);
}
