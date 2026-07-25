enum UserRole {
  directeur,
  chefProjet,
  acheteur;

  String get dbValue {
    switch (this) {
      case UserRole.directeur:
        return 'directeur';
      case UserRole.chefProjet:
        return 'chef_projet';
      case UserRole.acheteur:
        return 'acheteur';
    }
  }

  String get label {
    switch (this) {
      case UserRole.directeur:
        return 'Directeur';
      case UserRole.chefProjet:
        return 'Chef de projet';
      case UserRole.acheteur:
        return 'Acheteur';
    }
  }

  static UserRole fromDb(String value) {
    switch (value) {
      case 'directeur':
        return UserRole.directeur;
      case 'chef_projet':
        return UserRole.chefProjet;
      case 'acheteur':
        return UserRole.acheteur;
      default:
        return UserRole.chefProjet;
    }
  }
}
