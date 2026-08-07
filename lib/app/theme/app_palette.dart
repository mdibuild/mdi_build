import 'package:flutter/material.dart';

enum AppPaletteId { ardoiseNuit, blueprintClair, betonChaud }

class AppAccentOption {
  const AppAccentOption({required this.label, required this.color});

  final String label;
  final Color color;
}

class AppPalette {
  const AppPalette({
    required this.id,
    required this.label,
    required this.tagline,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textSoft,
    required this.success,
    required this.info,
    required this.danger,
    required this.purple,
    required this.accentOptions,
    required this.defaultAccentIndex,
  });

  final AppPaletteId id;
  final String label;
  final String tagline;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textSoft;
  final Color success;
  final Color info;
  final Color danger;
  final Color purple;
  final List<AppAccentOption> accentOptions;
  final int defaultAccentIndex;
}

const _semanticSuccess = Color(0xFF22C55E);
const _semanticInfo = Color(0xFF3B82F6);
const _semanticDanger = Color(0xFFEF4444);
const _semanticPurple = Color(0xFF7C3AED);

const appPalettes = <AppPaletteId, AppPalette>{
  AppPaletteId.ardoiseNuit: AppPalette(
    id: AppPaletteId.ardoiseNuit,
    label: 'Ardoise Nuit',
    tagline: 'Sombre — accent chantier',
    brightness: Brightness.dark,
    background: Color(0xFF0B1418),
    surface: Color(0xFF131F24),
    surfaceAlt: Color(0xFF1B2A30),
    border: Color(0xFF26383F),
    text: Color(0xFFF2F5F4),
    textSoft: Color(0xFF9FB3B8),
    success: _semanticSuccess,
    info: _semanticInfo,
    danger: _semanticDanger,
    purple: _semanticPurple,
    defaultAccentIndex: 0,
    accentOptions: [
      AppAccentOption(label: 'Jaune sécurité', color: Color(0xFFF2D21F)),
      AppAccentOption(label: 'Orange signal', color: Color(0xFFFF7A33)),
      AppAccentOption(label: 'Teal ferraille', color: Color(0xFF2DD4BF)),
      AppAccentOption(label: 'Bleu plan', color: Color(0xFF4C8DFF)),
    ],
  ),
  AppPaletteId.blueprintClair: AppPalette(
    id: AppPaletteId.blueprintClair,
    label: 'Blueprint Clair',
    tagline: 'Clair — technique, froid',
    brightness: Brightness.light,
    background: Color(0xFFF3F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAF0F3),
    border: Color(0xFFD7E1E6),
    text: Color(0xFF10242C),
    textSoft: Color(0xFF57707A),
    success: _semanticSuccess,
    info: _semanticInfo,
    danger: _semanticDanger,
    purple: _semanticPurple,
    defaultAccentIndex: 0,
    accentOptions: [
      AppAccentOption(label: 'Petrol actuel', color: Color(0xFF073B4C)),
      AppAccentOption(label: 'Bleu chantier', color: Color(0xFF2456B3)),
      AppAccentOption(label: 'Teal ferraille', color: Color(0xFF0E9488)),
      AppAccentOption(label: 'Jaune sécurité', color: Color(0xFFE7B800)),
    ],
  ),
  AppPaletteId.betonChaud: AppPalette(
    id: AppPaletteId.betonChaud,
    label: 'Béton Chaud',
    tagline: 'Clair — matière, chaud',
    brightness: Brightness.light,
    background: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFE9DC),
    border: Color(0xFFE2D9C4),
    text: Color(0xFF241B12),
    textSoft: Color(0xFF7A6D57),
    success: _semanticSuccess,
    info: _semanticInfo,
    danger: _semanticDanger,
    purple: _semanticPurple,
    defaultAccentIndex: 0,
    accentOptions: [
      AppAccentOption(label: 'Terracotta brique', color: Color(0xFFC1502E)),
      AppAccentOption(label: 'Ocre bâtiment', color: Color(0xFFC98A1A)),
      AppAccentOption(label: 'Vert chantier', color: Color(0xFF2F6B4F)),
      AppAccentOption(label: 'Petrol actuel', color: Color(0xFF073B4C)),
    ],
  ),
};
