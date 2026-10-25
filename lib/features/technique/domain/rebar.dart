/// Ronds à béton (acier HA) : conversions poids ⇄ longueur.
///
/// Masse linéique = section × masse volumique de l'acier (7 850 kg/m³) :
///   kg/m = π × d² / 4 × 7 850 / 1 000 000 ≈ 0,006165 × d²  (d en mm)
/// soit la règle de chantier « d² / 162 ».
library;

import 'dart:math' as math;

/// Diamètres commerciaux courants (mm).
const rebarDiameters = [6, 8, 10, 12, 14, 16, 20, 25, 32, 40];

/// Longueur commerciale d'une barre (m).
const standardBarLengthM = 12.0;

const steelDensityKgM3 = 7850.0;

/// Masse linéique en kg/m pour un diamètre en mm.
double rebarKgPerMeter(double diameterMm) =>
    math.pi * diameterMm * diameterMm / 4 * steelDensityKgM3 / 1e6;

/// Section d'une barre en cm².
double rebarSectionCm2(double diameterMm) =>
    math.pi * diameterMm * diameterMm / 4 / 100;

double rebarWeightKg({required double diameterMm, required double lengthM}) =>
    rebarKgPerMeter(diameterMm) * lengthM;

double rebarLengthM({required double diameterMm, required double weightKg}) {
  final perMeter = rebarKgPerMeter(diameterMm);
  return perMeter <= 0 ? 0 : weightKg / perMeter;
}

/// Nombre de barres commerciales nécessaires pour une longueur totale
/// (sans chutes ni recouvrements : à majorer selon le plan de ferraillage).
int barsForLength(double totalLengthM,
    {double barLengthM = standardBarLengthM}) {
  if (totalLengthM <= 0 || barLengthM <= 0) {
    return 0;
  }
  return (totalLengthM / barLengthM - 1e-9).ceil();
}

/// Une ligne de nomenclature : [count] barres de [lengthM] m en Ø[diameterMm].
class RebarLine {
  const RebarLine({
    required this.diameterMm,
    required this.count,
    required this.lengthM,
  });

  final int diameterMm;
  final int count;
  final double lengthM;

  double get totalLengthM => count * lengthM;
  double get weightKg =>
      rebarWeightKg(diameterMm: diameterMm.toDouble(), lengthM: totalLengthM);
}

/// Total par diamètre d'une nomenclature d'aciers.
class RebarSummary {
  RebarSummary(Iterable<RebarLine> lines, {this.wastePercent = 0}) {
    for (final line in lines) {
      if (line.count <= 0 || line.lengthM <= 0) {
        continue;
      }
      lengthByDiameter.update(line.diameterMm, (v) => v + line.totalLengthM,
          ifAbsent: () => line.totalLengthM);
    }
  }

  final double wastePercent;
  final Map<int, double> lengthByDiameter = {};

  List<int> get diameters => lengthByDiameter.keys.toList()..sort();

  double lengthOf(int d) =>
      (lengthByDiameter[d] ?? 0) * (1 + wastePercent / 100);
  double weightOf(int d) =>
      rebarWeightKg(diameterMm: d.toDouble(), lengthM: lengthOf(d));
  int barsOf(int d) => barsForLength(lengthOf(d));

  double get totalWeightKg => diameters.fold(0, (sum, d) => sum + weightOf(d));
}
