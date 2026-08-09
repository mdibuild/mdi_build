/// Distingue un particulier (aucun identifiant légal d'entreprise à saisir)
/// d'une entreprise/société (NIF, NIS, RC, article d'imposition requis pour
/// une facturation conforme à la législation algérienne).
enum EntityType {
  particulier,
  entreprise;

  String get dbValue {
    switch (this) {
      case EntityType.particulier:
        return 'particulier';
      case EntityType.entreprise:
        return 'entreprise';
    }
  }

  String get label {
    switch (this) {
      case EntityType.particulier:
        return 'Particulier';
      case EntityType.entreprise:
        return 'Entreprise';
    }
  }

  static EntityType fromDb(String value) {
    switch (value) {
      case 'particulier':
        return EntityType.particulier;
      case 'entreprise':
        return EntityType.entreprise;
      default:
        return EntityType.entreprise;
    }
  }
}
