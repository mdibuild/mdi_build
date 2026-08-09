import 'package:equatable/equatable.dart';

import '../enums/entity_type.dart';

class Client extends Equatable {
  const Client({
    required this.id,
    required this.companyId,
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.entityType,
    required this.legalNif,
    required this.legalNis,
    required this.legalRc,
    required this.legalArticleImposition,
    required this.notes,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final EntityType entityType;
  final String legalNif;
  final String legalNis;
  final String legalRc;
  final String legalArticleImposition;
  final String notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      name: (map['name'] as String?) ?? '',
      contactName: (map['contact_name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      entityType: EntityType.fromDb(
        (map['entity_type'] as String?) ?? 'entreprise',
      ),
      legalNif: (map['legal_nif'] as String?) ?? '',
      legalNis: (map['legal_nis'] as String?) ?? '',
      legalRc: (map['legal_rc'] as String?) ?? '',
      legalArticleImposition:
          (map['legal_article_imposition'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      isArchived: (map['is_archived'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'company_id': companyId,
      'name': name,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'entity_type': entityType.dbValue,
      'legal_nif': legalNif,
      'legal_nis': legalNis,
      'legal_rc': legalRc,
      'legal_article_imposition': legalArticleImposition,
      'notes': notes,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'entity_type': entityType.dbValue,
      'legal_nif': legalNif,
      'legal_nis': legalNis,
      'legal_rc': legalRc,
      'legal_article_imposition': legalArticleImposition,
      'notes': notes,
      'is_archived': isArchived,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Client copyWith({
    String? id,
    String? companyId,
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    EntityType? entityType,
    String? legalNif,
    String? legalNis,
    String? legalRc,
    String? legalArticleImposition,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      entityType: entityType ?? this.entityType,
      legalNif: legalNif ?? this.legalNif,
      legalNis: legalNis ?? this.legalNis,
      legalRc: legalRc ?? this.legalRc,
      legalArticleImposition:
          legalArticleImposition ?? this.legalArticleImposition,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        name,
        contactName,
        phone,
        email,
        address,
        entityType,
        legalNif,
        legalNis,
        legalRc,
        legalArticleImposition,
        notes,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
