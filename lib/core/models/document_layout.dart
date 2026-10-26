/// Mise en page des devis et factures : colonnes affichées et calcul des
/// remises (par ligne et globale).
library;

/// Colonnes du tableau des lignes. La désignation est toujours affichée.
enum LineColumn {
  quantity('quantity', 'Quantité'),
  unit('unit', 'Unité'),
  unitPrice('unit_price', 'Prix unitaire'),
  discount('discount', 'Remise %'),
  total('total', 'Montant');

  const LineColumn(this.key, this.label);

  /// Valeur enregistrée en base (colonne `hidden_columns`).
  final String key;
  final String label;

  static Set<LineColumn> fromKeys(Iterable<String> keys) => {
        for (final c in LineColumn.values)
          if (keys.contains(c.key)) c,
      };
}

/// Ligne chiffrée : quantité × PU, diminuée de sa remise.
class PricedLine {
  const PricedLine({
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  final double quantity;
  final double unitPrice;
  final double discountPercent;

  double get gross => quantity * unitPrice;
  double get discountAmount => gross * discountPercent / 100;
  double get net => gross - discountAmount;
}

/// Totaux d'un document :
///   brut = Σ (qté × PU) ; remises lignes ; sous-total = Σ lignes nettes ;
///   remise globale (%) ; HT net ; TVA ; TTC.
class DocumentTotals {
  DocumentTotals(
    Iterable<PricedLine> lines, {
    this.globalDiscountPercent = 0,
    this.taxRatePercent = 19,
  }) {
    for (final l in lines) {
      gross += l.gross;
      lineDiscounts += l.discountAmount;
    }
  }

  final double globalDiscountPercent;
  final double taxRatePercent;
  double gross = 0;
  double lineDiscounts = 0;

  /// Somme des lignes après leurs remises.
  double get subtotal => gross - lineDiscounts;
  double get globalDiscount => subtotal * globalDiscountPercent / 100;
  double get netHt => subtotal - globalDiscount;
  double get tax => netHt * taxRatePercent / 100;
  double get ttc => netHt + tax;

  /// Total de toutes les remises accordées.
  double get totalDiscount => lineDiscounts + globalDiscount;
  bool get hasDiscount => totalDiscount.abs() > 0.004;
}

/// Pourcentage de remise saisi, borné entre 0 et 100.
double clampPercent(double? value) => (value ?? 0).clamp(0, 100).toDouble();
