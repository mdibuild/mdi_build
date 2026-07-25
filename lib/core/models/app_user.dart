import '../enums/user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.companyId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String companyId;
  final String email;
  final String fullName;
  final UserRole role;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: UserRole.fromDb(map['role'] as String? ?? 'chef_projet'),
    );
  }
}
