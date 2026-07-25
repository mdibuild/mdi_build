enum RecordStatus {
  brouillon,
  enCours,
  valide,
  annule,
  termine,
  archive;

  String get dbValue {
    switch (this) {
      case RecordStatus.brouillon:
        return 'brouillon';
      case RecordStatus.enCours:
        return 'en_cours';
      case RecordStatus.valide:
        return 'valide';
      case RecordStatus.annule:
        return 'annule';
      case RecordStatus.termine:
        return 'termine';
      case RecordStatus.archive:
        return 'archive';
    }
  }

  String get label {
    switch (this) {
      case RecordStatus.brouillon:
        return 'Brouillon';
      case RecordStatus.enCours:
        return 'En cours';
      case RecordStatus.valide:
        return 'Validé';
      case RecordStatus.annule:
        return 'Annulé';
      case RecordStatus.termine:
        return 'Terminé';
      case RecordStatus.archive:
        return 'Archivé';
    }
  }

  static RecordStatus fromDb(String value) {
    switch (value) {
      case 'brouillon':
        return RecordStatus.brouillon;
      case 'en_cours':
        return RecordStatus.enCours;
      case 'valide':
        return RecordStatus.valide;
      case 'annule':
        return RecordStatus.annule;
      case 'termine':
        return RecordStatus.termine;
      case 'archive':
        return RecordStatus.archive;
      default:
        return RecordStatus.brouillon;
    }
  }
}
