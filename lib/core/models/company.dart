import 'package:equatable/equatable.dart';

class Company extends Equatable {
  const Company({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.legalNif,
    required this.legalNis,
    required this.legalRc,
    required this.legalArticleImposition,
    required this.logoPath,
    required this.bankName,
    required this.bankRib,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String legalNif;
  final String legalNis;
  final String legalRc;
  final String legalArticleImposition;
  final String? logoPath;
  final String bankName;
  final String bankRib;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      legalNif: (map['legal_nif'] as String?) ?? '',
      legalNis: (map['legal_nis'] as String?) ?? '',
      legalRc: (map['legal_rc'] as String?) ?? '',
      legalArticleImposition:
          (map['legal_article_imposition'] as String?) ?? '',
      logoPath: map['logo_path'] as String?,
      bankName: (map['bank_name'] as String?) ?? '',
      bankRib: (map['bank_rib'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'legal_nif': legalNif,
      'legal_nis': legalNis,
      'legal_rc': legalRc,
      'legal_article_imposition': legalArticleImposition,
      'logo_path': logoPath,
      'bank_name': bankName,
      'bank_rib': bankRib,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? legalNif,
    String? legalNis,
    String? legalRc,
    String? legalArticleImposition,
    String? logoPath,
    bool clearLogoPath = false,
    String? bankName,
    String? bankRib,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      legalNif: legalNif ?? this.legalNif,
      legalNis: legalNis ?? this.legalNis,
      legalRc: legalRc ?? this.legalRc,
      legalArticleImposition:
          legalArticleImposition ?? this.legalArticleImposition,
      logoPath: clearLogoPath ? null : logoPath ?? this.logoPath,
      bankName: bankName ?? this.bankName,
      bankRib: bankRib ?? this.bankRib,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        address,
        legalNif,
        legalNis,
        legalRc,
        legalArticleImposition,
        logoPath,
        bankName,
        bankRib,
        createdAt,
        updatedAt,
      ];
}
