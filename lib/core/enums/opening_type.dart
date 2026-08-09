enum OpeningType {
  porte,
  fenetre,
  porteFenetre,
  baieVitree,
  autre;

  String get dbValue {
    switch (this) {
      case OpeningType.porte:
        return 'porte';
      case OpeningType.fenetre:
        return 'fenetre';
      case OpeningType.porteFenetre:
        return 'porte_fenetre';
      case OpeningType.baieVitree:
        return 'baie_vitree';
      case OpeningType.autre:
        return 'autre';
    }
  }

  String get label {
    switch (this) {
      case OpeningType.porte:
        return 'Porte';
      case OpeningType.fenetre:
        return 'Fenêtre';
      case OpeningType.porteFenetre:
        return 'Porte-fenêtre';
      case OpeningType.baieVitree:
        return 'Baie vitrée';
      case OpeningType.autre:
        return 'Autre';
    }
  }

  static OpeningType fromDb(String value) {
    switch (value) {
      case 'porte':
        return OpeningType.porte;
      case 'fenetre':
        return OpeningType.fenetre;
      case 'porte_fenetre':
        return OpeningType.porteFenetre;
      case 'baie_vitree':
        return OpeningType.baieVitree;
      default:
        return OpeningType.autre;
    }
  }
}
