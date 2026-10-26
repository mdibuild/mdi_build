import 'package:flutter/material.dart';

import '../../core/models/document_layout.dart';
import 'premium_ui.dart';

/// Réglages d'affichage d'un devis ou d'une facture : colonnes visibles sur
/// le PDF et remise globale.
class DocumentLayoutCard extends StatelessWidget {
  const DocumentLayoutCard({
    super.key,
    required this.hiddenColumns,
    required this.onToggleColumn,
    required this.discountController,
    required this.onDiscountChanged,
  });

  final Set<LineColumn> hiddenColumns;
  final void Function(LineColumn column, bool visible) onToggleColumn;
  final TextEditingController discountController;
  final ValueChanged<String> onDiscountChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSectionHeader(
            title: 'Remise et colonnes du document',
            subtitle: 'Choisis ce qui apparaît sur le PDF (la désignation '
                'est toujours affichée).',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final column in LineColumn.values)
                FilterChip(
                  label: Text(column.label),
                  selected: !hiddenColumns.contains(column),
                  onSelected: (visible) => onToggleColumn(column, visible),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 240,
            child: TextField(
              controller: discountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: onDiscountChanged,
              decoration: const InputDecoration(
                labelText: 'Remise globale',
                suffixText: '%',
                helperText: 'Appliquée après les remises de ligne',
                prefixIcon: Icon(Icons.percent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lignes de totaux avec remises, pour l'écran (montants en DA).
List<(String, double, bool)> totalsLines(DocumentTotals t) => [
      if (t.hasDiscount) ...[
        ('Total brut HT', t.gross, false),
        if (t.lineDiscounts > 0.004)
          ('Remises sur lignes', -t.lineDiscounts, false),
        if (t.globalDiscount > 0.004)
          (
            'Remise globale ${_pct(t.globalDiscountPercent)} %',
            -t.globalDiscount,
            false
          ),
      ],
      ('Total HT', t.netHt, false),
      ('TVA ${_pct(t.taxRatePercent)} %', t.tax, false),
      ('Total TTC', t.ttc, true),
    ];

String _pct(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2).replaceAll('.', ',');
