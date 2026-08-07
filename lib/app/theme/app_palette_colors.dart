import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppPaletteColors extends ThemeExtension<AppPaletteColors> {
  const AppPaletteColors({
    required this.petrol,
    required this.petrolAlt,
    required this.petrolSoft,
    required this.yellow,
    required this.yellowSoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textSoft,
    required this.border,
    required this.success,
    required this.info,
    required this.danger,
    required this.purple,
  });

  final Color petrol;
  final Color petrolAlt;
  final Color petrolSoft;
  final Color yellow;
  final Color yellowSoft;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color textSoft;
  final Color border;
  final Color success;
  final Color info;
  final Color danger;
  final Color purple;

  @override
  AppPaletteColors copyWith({
    Color? petrol,
    Color? petrolAlt,
    Color? petrolSoft,
    Color? yellow,
    Color? yellowSoft,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? text,
    Color? textSoft,
    Color? border,
    Color? success,
    Color? info,
    Color? danger,
    Color? purple,
  }) {
    return AppPaletteColors(
      petrol: petrol ?? this.petrol,
      petrolAlt: petrolAlt ?? this.petrolAlt,
      petrolSoft: petrolSoft ?? this.petrolSoft,
      yellow: yellow ?? this.yellow,
      yellowSoft: yellowSoft ?? this.yellowSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      text: text ?? this.text,
      textSoft: textSoft ?? this.textSoft,
      border: border ?? this.border,
      success: success ?? this.success,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      purple: purple ?? this.purple,
    );
  }

  @override
  AppPaletteColors lerp(ThemeExtension<AppPaletteColors>? other, double t) {
    if (other is! AppPaletteColors) {
      return this;
    }

    return AppPaletteColors(
      petrol: Color.lerp(petrol, other.petrol, t)!,
      petrolAlt: Color.lerp(petrolAlt, other.petrolAlt, t)!,
      petrolSoft: Color.lerp(petrolSoft, other.petrolSoft, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      yellowSoft: Color.lerp(yellowSoft, other.yellowSoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
    );
  }
}

AppPaletteColors resolvePaletteColors(AppPalette palette, int accentIndex) {
  final safeIndex = accentIndex.clamp(0, palette.accentOptions.length - 1);
  final accent = palette.accentOptions[safeIndex].color;

  final hsl = HSLColor.fromColor(accent);
  final alt = hsl
      .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
      .toColor();
  final soft = Color.alphaBlend(
    accent.withValues(alpha: 0.12),
    palette.surface,
  );

  return AppPaletteColors(
    petrol: accent,
    petrolAlt: alt,
    petrolSoft: soft,
    yellow: accent,
    yellowSoft: soft,
    background: palette.background,
    surface: palette.surface,
    surfaceAlt: palette.surfaceAlt,
    text: palette.text,
    textSoft: palette.textSoft,
    border: palette.border,
    success: palette.success,
    info: palette.info,
    danger: palette.danger,
    purple: palette.purple,
  );
}

extension AppPaletteAccess on BuildContext {
  AppPaletteColors get palette => Theme.of(this).extension<AppPaletteColors>()!;
}
