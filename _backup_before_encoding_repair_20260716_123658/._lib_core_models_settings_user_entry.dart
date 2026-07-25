import 'package:equatable/equatable.dart';

class SettingsUserEntry extends Equatable {
  const SettingsUserEntry({
    required this.id,
    required this.companyId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String displayName;
  final String email;
  final String role;
  final DateTime? createdAt;

  factory SettingsUserEntry.fromMap(Map<String, dynamic> map) {
    return SettingsUserEntry(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      displayName: (map['full_name'] as String?) ??
          (map['display_name'] as String?) ??
          (map['name'] as String?) ??
          'Utilisateur',
      email: (map['email'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'member',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        displayName,
        email,
        role,
        createdAt,
      ];
}
