enum SpaceType {
  piece,
  facade,
  toiture,
  fondation,
  cloture,
  espaceExterieur;

  String get dbValue {
    switch (this) {
      case SpaceType.piece:
        return 'piece';
      case SpaceType.facade:
        return 'facade';
      case SpaceType.toiture:
        return 'toiture';
      case SpaceType.fondation:
        return 'fondation';
      case SpaceType.cloture:
        return 'cloture';
      case SpaceType.espaceExterieur:
        return 'espace_exterieur';
    }
  }

  String get label {
    switch (this) {
      case SpaceType.piece:
        return 'Pièce';
      case SpaceType.facade:
        return 'Façade';
      case SpaceType.toiture:
        return 'Toiture';
      case SpaceType.fondation:
        return 'Fondation';
      case SpaceType.cloture:
        return 'Clôture';
      case SpaceType.espaceExterieur:
        return 'Espace extérieur';
    }
  }

  static SpaceType fromDb(String value) {
    switch (value) {
      case 'piece':
        return SpaceType.piece;
      case 'facade':
        return SpaceType.facade;
      case 'toiture':
        return SpaceType.toiture;
      case 'fondation':
        return SpaceType.fondation;
      case 'cloture':
        return SpaceType.cloture;
      case 'espace_exterieur':
        return SpaceType.espaceExterieur;
      default:
        return SpaceType.piece;
    }
  }
}
