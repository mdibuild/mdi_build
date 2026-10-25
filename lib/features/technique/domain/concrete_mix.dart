/// Formulation indicative du béton à partir de la résistance visée (MPa).
///
/// Dosages courants de chantier pour 1 m³ de béton en place : ciment
/// CEM II / CPJ 42,5, granulats secs mesurés en vrac (volumes apparents),
/// sable 0/5 et gravier 5/25. Ce sont des ordres de grandeur : au-delà de
/// 25 MPa, ou pour un ouvrage important, une étude de formulation en
/// laboratoire (et des essais d'écrasement) reste indispensable.
library;

import 'dart:math' as math;

class ConcreteGrade {
  const ConcreteGrade({
    required this.mpa,
    required this.label,
    required this.usage,
    required this.cementKg,
    required this.sandL,
    required this.gravelL,
    required this.waterL,
  });

  /// Résistance caractéristique visée à 28 jours.
  final double mpa;
  final String label;
  final String usage;

  /// Quantités pour 1 m³ de béton.
  final double cementKg;
  final double sandL;
  final double gravelL;
  final double waterL;

  double get waterCementRatio => waterL / cementKg;
}

const concreteGrades = <ConcreteGrade>[
  ConcreteGrade(
    mpa: 10,
    label: 'Béton de propreté',
    usage: 'Propreté, calage, remplissage',
    cementKg: 150,
    sandL: 400,
    gravelL: 800,
    waterL: 120,
  ),
  ConcreteGrade(
    mpa: 16,
    label: 'Béton maigre',
    usage: 'Gros béton, dallage non armé, regards',
    cementKg: 250,
    sandL: 400,
    gravelL: 800,
    waterL: 150,
  ),
  ConcreteGrade(
    mpa: 20,
    label: 'Béton courant',
    usage: 'Semelles, longrines, fondations',
    cementKg: 300,
    sandL: 400,
    gravelL: 800,
    waterL: 165,
  ),
  ConcreteGrade(
    mpa: 25,
    label: 'Béton armé',
    usage: 'Poteaux, poutres, dalles, voiles',
    cementKg: 350,
    sandL: 400,
    gravelL: 800,
    waterL: 175,
  ),
  ConcreteGrade(
    mpa: 30,
    label: 'Béton armé renforcé',
    usage: 'Ouvrages fortement sollicités, réservoirs',
    cementKg: 400,
    sandL: 380,
    gravelL: 800,
    waterL: 190,
  ),
  ConcreteGrade(
    mpa: 35,
    label: 'Béton haute résistance',
    usage: 'Ouvrages spéciaux (étude obligatoire)',
    cementKg: 450,
    sandL: 360,
    gravelL: 780,
    waterL: 200,
  ),
];

/// Dosage pour une résistance quelconque : interpolation linéaire entre
/// les lignes du tableau (bornée aux valeurs extrêmes).
ConcreteGrade gradeForMpa(double mpa) {
  const grades = concreteGrades;
  if (mpa <= grades.first.mpa) {
    return grades.first;
  }
  if (mpa >= grades.last.mpa) {
    return grades.last;
  }
  for (var i = 0; i < grades.length - 1; i++) {
    final a = grades[i];
    final b = grades[i + 1];
    if (mpa == a.mpa) {
      return a;
    }
    if (mpa > a.mpa && mpa < b.mpa) {
      final t = (mpa - a.mpa) / (b.mpa - a.mpa);
      double lerp(double x, double y) => x + (y - x) * t;
      return ConcreteGrade(
        mpa: mpa,
        label: 'Béton ${mpa.toStringAsFixed(mpa % 1 == 0 ? 0 : 1)} MPa',
        usage:
            'Dosage interpolé entre ${a.mpa.toInt()} et ${b.mpa.toInt()} MPa',
        cementKg: lerp(a.cementKg, b.cementKg),
        sandL: lerp(a.sandL, b.sandL),
        gravelL: lerp(a.gravelL, b.gravelL),
        waterL: lerp(a.waterL, b.waterL),
      );
    }
  }
  return grades.last;
}

/// Quantités à commander pour un volume donné.
class ConcreteQuantities {
  ConcreteQuantities({
    required this.grade,
    required this.volumeM3,
    this.wastePercent = 5,
    this.bagKg = 50,
    this.wheelbarrowL = 60,
    this.bucketL = 10,
  });

  final ConcreteGrade grade;
  final double volumeM3;
  final double wastePercent;
  final double bagKg;
  final double wheelbarrowL;
  final double bucketL;

  /// Volume commandé, pertes comprises.
  double get orderedVolume => volumeM3 * (1 + wastePercent / 100);

  double get cementKg => grade.cementKg * orderedVolume;
  double get cementBags => cementKg / bagKg;
  int get cementBagsRounded => _ceil(cementBags);

  double get sandL => grade.sandL * orderedVolume;
  double get sandM3 => sandL / 1000;
  int get sandWheelbarrows => _ceil(sandL / wheelbarrowL);

  double get gravelL => grade.gravelL * orderedVolume;
  double get gravelM3 => gravelL / 1000;
  int get gravelWheelbarrows => _ceil(gravelL / wheelbarrowL);

  double get waterL => grade.waterL * orderedVolume;

  /// Recette « par sac » : ce qu'il faut mélanger avec un sac de ciment.
  double get sandPerBagL => grade.sandL * bagKg / grade.cementKg;
  double get gravelPerBagL => grade.gravelL * bagKg / grade.cementKg;
  double get waterPerBagL => grade.waterL * bagKg / grade.cementKg;
  double get sandPerBagWheelbarrows => sandPerBagL / wheelbarrowL;
  double get gravelPerBagWheelbarrows => gravelPerBagL / wheelbarrowL;
  double get sandPerBagBuckets => sandPerBagL / bucketL;
  double get gravelPerBagBuckets => gravelPerBagL / bucketL;
  double get waterPerBagBuckets => waterPerBagL / bucketL;

  /// Volume de béton obtenu avec un sac.
  double get concretePerBagM3 => bagKg / grade.cementKg;

  static int _ceil(double v) => v <= 0 ? 0 : (v - 1e-9).ceil();
}

/// Volume d'un élément rectangulaire (dalle, semelle, poutre) en m³.
double rectangularVolume({
  required double lengthM,
  required double widthM,
  required double thicknessM,
  int count = 1,
}) =>
    lengthM * widthM * thicknessM * count;

/// Volume d'un poteau ou pieu circulaire (diamètre en m) en m³.
double cylinderVolume({
  required double diameterM,
  required double heightM,
  int count = 1,
}) =>
    math.pi * diameterM * diameterM / 4 * heightM * count;
