import 'package:equatable/equatable.dart';

class Company extends Equatable {
  const Company({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.legalIce,
    required this.legalIf,
    required this.legalRc,
    required this.legalPatente,
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
  final String legalIce;
  final String legalIf;
  final String legalRc;
  final String legalPatente;
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
      legalIce: (map['legal_ice'] as String?) ?? '',
      legalIf: (map['legal_if'] as String?) ?? '',
      legalRc: (map['legal_rc'] as String?) ?? '',
      legalPatente: (map['legal_patente'] as String?) ?? '',
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
      'legal_ice': legalIce,
      'legal_if': legalIf,
      'legal_rc': legalRc,
      'legal_patente': legalPatente,
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
    String? legalIce,
    String? legalIf,
    String? legalRc,
    String? legalPatente,
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
      legalIce: legalIce ?? this.legalIce,
      legalIf: legalIf ?? this.legalIf,
      legalRc: legalRc ?? this.legalRc,
      legalPatente: legalPatente ?? this.legalPatente,
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
        legalIce,
        legalIf,
        legalRc,
        legalPatente,
        logoPath,
        bankName,
        bankRib,
        createdAt,
        updatedAt,
      ];
}
