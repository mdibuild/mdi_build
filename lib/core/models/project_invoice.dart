import 'document_layout.dart';

/// Facture d'un chantier. Elle peut être créée depuis un devis (lignes
/// recopiées) ou saisie directement.
class ProjectInvoice {
  const ProjectInvoice({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.number,
    required this.title,
    required this.status,
    required this.issueDate,
    required this.taxRate,
    required this.amountPaid,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.quoteId,
    this.clientId,
    this.dueDate,
    this.createdBy,
    this.discountPercent = 0,
    this.hiddenColumns = const [],
    this.layoutStored = false,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String? quoteId;
  final String? clientId;

  /// Numéro unique dans l'entreprise, ex. FAC-2026-007.
  final String number;
  final String title;

  /// brouillon, emise, partielle, payee, annulee.
  final String status;
  final DateTime issueDate;
  final DateTime? dueDate;

  /// Taux de TVA en pourcentage (19 = 19 %).
  final double taxRate;
  final double amountPaid;
  final String notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Remise globale (%) appliquée après les remises de ligne.
  final double discountPercent;

  /// Colonnes masquées sur le PDF (clés de [LineColumn]).
  final List<String> hiddenColumns;

  /// La base possède les colonnes de mise en page (v2.1).
  final bool layoutStored;

  static const statuses = [
    'brouillon',
    'emise',
    'partielle',
    'payee',
    'annulee'
  ];

  static String statusLabel(String status) => switch (status) {
        'brouillon' => 'Brouillon',
        'emise' => 'Émise',
        'partielle' => 'Payée en partie',
        'payee' => 'Payée',
        'annulee' => 'Annulée',
        _ => status,
      };

  /// Échéance dépassée alors qu'il reste à payer.
  bool isOverdue(double totalTtc, {DateTime? today}) {
    final due = dueDate;
    if (due == null ||
        status == 'payee' ||
        status == 'annulee' ||
        status == 'brouillon') {
      return false;
    }
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return day.isAfter(due) && amountPaid < totalTtc - 0.005;
  }

  factory ProjectInvoice.fromMap(Map<String, dynamic> map) {
    return ProjectInvoice(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      projectId: map['project_id'] as String,
      quoteId: map['quote_id']?.toString(),
      clientId: map['client_id']?.toString(),
      number: map['number'] as String? ?? '',
      title: map['title'] as String? ?? 'Facture',
      status: map['status'] as String? ?? 'brouillon',
      issueDate: _date(map['issue_date']) ?? DateTime.now(),
      dueDate: _date(map['due_date']),
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 19,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdBy: map['created_by']?.toString(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
      hiddenColumns: [
        for (final c in (map['hidden_columns'] as List<dynamic>?) ?? const [])
          c.toString(),
      ],
      layoutStored: map.containsKey('discount_percent'),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'company_id': companyId,
        'project_id': projectId,
        'created_by': createdBy,
        ...toUpdateMap(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'quote_id': quoteId,
        'client_id': clientId,
        'number': number,
        'title': title,
        'status': status,
        'issue_date': _dateText(issueDate),
        'due_date': dueDate == null ? null : _dateText(dueDate!),
        'tax_rate': taxRate,
        'amount_paid': amountPaid,
        'notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (layoutStored || discountPercent != 0)
          'discount_percent': discountPercent,
        if (layoutStored || hiddenColumns.isNotEmpty)
          'hidden_columns': hiddenColumns,
      };

  ProjectInvoice copyWith({
    String? id,
    String? number,
    String? title,
    String? status,
    DateTime? issueDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    double? taxRate,
    double? amountPaid,
    String? notes,
    String? clientId,
    bool clearClient = false,
    double? discountPercent,
    List<String>? hiddenColumns,
  }) {
    return ProjectInvoice(
      id: id ?? this.id,
      companyId: companyId,
      projectId: projectId,
      quoteId: quoteId,
      clientId: clearClient ? null : clientId ?? this.clientId,
      number: number ?? this.number,
      title: title ?? this.title,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      taxRate: taxRate ?? this.taxRate,
      amountPaid: amountPaid ?? this.amountPaid,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      discountPercent: discountPercent ?? this.discountPercent,
      hiddenColumns: hiddenColumns ?? this.hiddenColumns,
      layoutStored: layoutStored,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Ligne de facture (désignation, quantité, unité, prix unitaire HT).
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.id = '',
    this.invoiceId = '',
    this.sortOrder = 0,
    this.discountPercent = 0,
  });

  final String id;
  final String invoiceId;
  final String label;
  final double quantity;
  final String unit;
  final double unitPrice;
  final int sortOrder;

  /// Remise de la ligne en pourcentage (0 à 100).
  final double discountPercent;

  double get grossTotal => quantity * unitPrice;
  double get total => grossTotal * (1 - discountPercent / 100);

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) => InvoiceLineItem(
        id: map['id'] as String,
        invoiceId: map['invoice_id'] as String,
        label: map['label'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unit: map['unit'] as String? ?? 'u',
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsertMap(String invoiceId, int sortOrder) => {
        'invoice_id': invoiceId,
        'label': label,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'sort_order': sortOrder,
        if (discountPercent != 0) 'discount_percent': discountPercent,
      };
}

/// Totaux d'une facture, calculés comme dans le devis (HT = somme des
/// lignes, TVA au taux de la facture, TTC = HT + TVA).
class InvoiceTotals {
  InvoiceTotals(List<InvoiceLineItem> items, double taxRate, double paid,
      {double globalDiscountPercent = 0})
      : document = DocumentTotals(
          [
            for (final i in items)
              PricedLine(
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                discountPercent: i.discountPercent,
              ),
          ],
          globalDiscountPercent: globalDiscountPercent,
          taxRatePercent: taxRate,
        ),
        rate = taxRate,
        amountPaid = paid;

  /// Détail brut / remises / HT net.
  final DocumentTotals document;
  final double rate;
  final double amountPaid;

  /// Total HT après toutes les remises.
  double get ht => document.netHt;

  double get tax => ht * rate / 100;
  double get ttc => ht + tax;
  double get remaining => (ttc - amountPaid).clamp(0, double.infinity);

  /// Statut cohérent avec le montant payé (le brouillon et l'annulation
  /// restent des choix manuels).
  static String statusFor(String current, double ttc, double paid) {
    if (current == 'brouillon' || current == 'annulee') {
      return current;
    }
    if (paid <= 0.005) {
      return 'emise';
    }
    return paid >= ttc - 0.005 ? 'payee' : 'partielle';
  }
}

/// Prochain numéro de facture de l'année : FAC-AAAA-NNN.
String nextInvoiceNumber(Iterable<String> existing, int year) {
  final prefix = 'FAC-$year-';
  var max = 0;
  for (final n in existing) {
    if (n.startsWith(prefix)) {
      final value = int.tryParse(n.substring(prefix.length)) ?? 0;
      if (value > max) {
        max = value;
      }
    }
  }
  return '$prefix${(max + 1).toString().padLeft(3, '0')}';
}
