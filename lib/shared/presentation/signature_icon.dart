import 'package:flutter/material.dart';

/// Couleurs de la signature MDI Build, fixes quelle que soit la palette.
class BrandColors {
  BrandColors._();

  static const petrol = Color(0xFF0B2436);
  static const petrolLight = Color(0xFF1B4A66);
  static const gold = Color(0xFFF2C230);
  static const ochre = Color(0xFFC98A1E);
}

/// Icône signature de l'application : pictogramme doré dégradé vers l'ocre,
/// sur un petit carré bleu pétrole « estampé » (relief clair en haut,
/// ombre portée en bas, liseré doré).
class SignatureIcon extends StatelessWidget {
  const SignatureIcon(
    this.icon, {
    super.key,
    this.size = 38,
    this.highlighted = false,
  });

  final IconData icon;

  /// Côté du carré (l'icône occupe un peu plus de la moitié).
  final double size;

  /// Liseré doré plus marqué (entrée de menu active, par exemple).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.petrolLight, BrandColors.petrol],
        ),
        border: Border.all(
          color: BrandColors.gold.withValues(alpha: highlighted ? 0.95 : 0.45),
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reflet du relief sur la moitié haute.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BrandColors.gold, BrandColors.ochre],
            ).createShader(bounds),
            child: Icon(icon, size: size * 0.56, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
