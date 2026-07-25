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
        return 'PiÃƒÆ’Ã‚Â¨ce';
      case SpaceType.facade:
        return 'FaÃƒÆ’Ã‚Â§ade';
      case SpaceType.toiture:
        return 'Toiture';
      case SpaceType.fondation:
        return 'Fondation';
      case SpaceType.cloture:
        return 'ClÃƒÆ’Ã‚Â´ture';
      case SpaceType.espaceExterieur:
        return 'Espace extÃƒÆ’Ã‚Â©rieur';
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
