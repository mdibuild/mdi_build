import '../enums/entity_type.dart';
import '../models/client.dart';
import '../models/supplier.dart';

/// Lignes de coordonnées d'un client ou d'un fournisseur, prêtes à afficher
/// dans un PDF ou un rapport (les champs vides sont omis).
List<String> partyDetailLines({
  required String contactName,
  required String phone,
  required String email,
  required String address,
  required EntityType entityType,
  required String legalNif,
  required String legalNis,
  required String legalRc,
  required String legalArticleImposition,
}) {
  final lines = <String>[];
  void add(String prefix, String value) {
    final v = value.trim();
    if (v.isNotEmpty) {
      lines.add(prefix.isEmpty ? v : '$prefix : $v');
    }
  }

  add('Contact', contactName);
  add('', address);
  add('Tél.', phone);
  add('E-mail', email);
  if (entityType == EntityType.entreprise) {
    add('NIF', legalNif);
    add('NIS', legalNis);
    add('RC', legalRc);
    add('Art. imposition', legalArticleImposition);
  }
  return lines;
}

List<String> clientDetailLines(Client c) => partyDetailLines(
      contactName: c.contactName,
      phone: c.phone,
      email: c.email,
      address: c.address,
      entityType: c.entityType,
      legalNif: c.legalNif,
      legalNis: c.legalNis,
      legalRc: c.legalRc,
      legalArticleImposition: c.legalArticleImposition,
    );

List<String> supplierDetailLines(Supplier s) => partyDetailLines(
      contactName: s.contactName,
      phone: s.phone,
      email: s.email,
      address: s.address,
      entityType: s.entityType,
      legalNif: s.legalNif,
      legalNis: s.legalNis,
      legalRc: s.legalRc,
      legalArticleImposition: s.legalArticleImposition,
    );
