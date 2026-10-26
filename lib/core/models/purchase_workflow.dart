/// Suivi des achats : étapes du besoin à la livraison, et historique.
///
///   Besoin émis → (Validé DG) → En traitement (acheteur : demande de
///   devis / proforma au fournisseur) → Commandé (n° BC attribué) → Livré.
library;

class PurchaseWorkflow {
  PurchaseWorkflow._();

  /// Ordre d'affichage des étapes.
  static const steps = [
    'brouillon',
    'dg_valide',
    'en_traitement',
    'commande',
    'livre',
  ];

  static const statuses = [...steps, 'annule', 'archive'];

  static String label(String status) => switch (status) {
        'brouillon' => 'Besoin émis',
        'dg_valide' => 'Validé DG',
        'en_traitement' => 'En traitement',
        'commande' => 'Commandé',
        'livre' => 'Livré',
        'annule' => 'Annulé',
        'archive' => 'Archivé',
        _ => status,
      };

  /// Libellé du bouton qui fait passer à cette étape.
  static String actionLabel(String status) => switch (status) {
        'dg_valide' => 'Valider (DG)',
        'en_traitement' => 'Prendre en charge',
        'commande' => 'Commander',
        'livre' => 'Réceptionner',
        _ => label(status),
      };

  /// Étapes suivantes possibles depuis [status].
  static List<String> nextSteps(String status) => switch (status) {
        'brouillon' => const ['dg_valide', 'en_traitement'],
        'dg_valide' => const ['en_traitement', 'commande'],
        'en_traitement' => const ['commande'],
        'commande' => const ['livre'],
        _ => const [],
      };

  /// Rang de l'étape (-1 pour annulé / archivé).
  static int rank(String status) => steps.indexOf(status);
}

/// Numéro de bon de commande suivant : BC-AAAA-NNN.
String nextOrderNumber(Iterable<String?> existing, int year) {
  final prefix = 'BC-$year-';
  var max = 0;
  for (final n in existing) {
    if (n != null && n.startsWith(prefix)) {
      final v = int.tryParse(n.substring(prefix.length)) ?? 0;
      if (v > max) {
        max = v;
      }
    }
  }
  return '$prefix${(max + 1).toString().padLeft(3, '0')}';
}

/// Évènement de l'historique d'un achat.
class PurchaseEvent {
  const PurchaseEvent({
    required this.id,
    required this.purchaseId,
    required this.kind,
    required this.createdAt,
    this.status,
    this.comment = '',
    this.actorName = '',
  });

  final String id;
  final String purchaseId;

  /// creation, statut, modification, piece_jointe, commentaire.
  final String kind;
  final String? status;
  final String comment;
  final String actorName;
  final DateTime createdAt;

  String get title => switch (kind) {
        'creation' => 'Besoin émis',
        'statut' => PurchaseWorkflow.label(status ?? ''),
        'modification' => 'Achat modifié',
        'piece_jointe' => 'Pièce jointe ajoutée',
        _ => 'Commentaire',
      };

  factory PurchaseEvent.fromMap(Map<String, dynamic> map) => PurchaseEvent(
        id: map['id'] as String,
        purchaseId: map['purchase_id'] as String,
        kind: map['kind'] as String? ?? 'commentaire',
        status: map['status']?.toString(),
        comment: map['comment'] as String? ?? '',
        actorName: map['actor_name'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
