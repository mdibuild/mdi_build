import 'package:equatable/equatable.dart';

class Client extends Equatable {
  const Client({
    required this.id,
    required this.companyId,
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.taxId,
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
  final String taxId;
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
      taxId: (map['tax_id'] as String?) ?? '',
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
      'tax_id': taxId,
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
      'tax_id': taxId,
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
    String? taxId,
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
      taxId: taxId ?? this.taxId,
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
        taxId,
        notes,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
