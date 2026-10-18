import 'package:flutter/material.dart';

import '../../app/theme/app_palette_colors.dart';
import '../../app/theme/app_spacing.dart';

const _premiumCardShadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  ),
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 14),
  ),
];

const _premiumCardShadowHovered = [
  BoxShadow(
    color: Color(0x0C000000),
    blurRadius: 6,
    offset: Offset(0, 3),
  ),
  BoxShadow(
    color: Color(0x1C000000),
    blurRadius: 30,
    offset: Offset(0, 18),
  ),
];

class PremiumSurfaceCard extends StatefulWidget {
  const PremiumSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  State<PremiumSurfaceCard> createState() => _PremiumSurfaceCardState();
}

class _PremiumSurfaceCardState extends State<PremiumSurfaceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.border,
          width: 1.2,
        ),
        boxShadow: _hovered ? _premiumCardShadowHovered : _premiumCardShadow,
      ),
      transform: _hovered
          ? Matrix4.translationValues(0, -2, 0)
          : Matrix4.identity(),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (widget.onTap == null) {
      return content;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

class PremiumHeroHeader extends StatelessWidget {
  const PremiumHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.petrol,
                colors.petrolAlt,
              ],
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'MDI',
                            style: TextStyle(
                              color: colors.yellow,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.88),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _HeroActionsTheme(child: trailing!),
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'MDI',
                        style: TextStyle(
                          color: colors.yellow,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      Flexible(child: _HeroActionsTheme(child: trailing!)),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// Adapte les boutons posés sur le fond couleur de marque de l'en-tête :
/// action principale en jaune de marque, action secondaire en contour blanc,
/// pour qu'elles restent bien visibles et lisibles.
class _HeroActionsTheme extends StatelessWidget {
  const _HeroActionsTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.palette;
    final onHighlight =
        ThemeData.estimateBrightnessForColor(colors.yellow) == Brightness.light
            ? (ThemeData.estimateBrightnessForColor(colors.petrol) ==
                    Brightness.dark
                ? colors.petrol
                : const Color(0xFF14232A))
            : Colors.white;

    Color? disabledOr(Set<WidgetState> states, Color color) =>
        states.contains(WidgetState.disabled)
            ? Colors.white.withValues(alpha: 0.6)
            : color;

    final primary = (theme.elevatedButtonTheme.style ?? const ButtonStyle())
        .copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.white.withValues(alpha: 0.22)
            : colors.yellow,
      ),
      foregroundColor:
          WidgetStateProperty.resolveWith((s) => disabledOr(s, onHighlight)),
      iconColor:
          WidgetStateProperty.resolveWith((s) => disabledOr(s, onHighlight)),
      overlayColor: WidgetStatePropertyAll(
        onHighlight.withValues(alpha: 0.10),
      ),
      shadowColor: WidgetStatePropertyAll(
        Colors.black.withValues(alpha: 0.25),
      ),
    );

    final secondary = (theme.outlinedButtonTheme.style ?? const ButtonStyle())
        .copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor:
          WidgetStateProperty.resolveWith((s) => disabledOr(s, Colors.white)),
      iconColor:
          WidgetStateProperty.resolveWith((s) => disabledOr(s, Colors.white)),
      side: WidgetStatePropertyAll(
        BorderSide(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
      ),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.12),
      ),
    );

    return Theme(
      data: theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(style: primary),
        filledButtonTheme: FilledButtonThemeData(style: primary),
        outlinedButtonTheme: OutlinedButtonThemeData(style: secondary),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      child: child,
    );
  }
}

/// Styles de boutons partagés hors thème.
class PremiumButtonStyles {
  PremiumButtonStyles._();

  /// Action destructive (supprimer, déconnecter…) : fond rouge, texte blanc.
  static ButtonStyle destructive(BuildContext context) {
    final colors = context.palette;
    return FilledButton.styleFrom(
      backgroundColor: colors.danger,
      foregroundColor: Colors.white,
      iconColor: Colors.white,
      disabledBackgroundColor: colors.border,
      disabledForegroundColor: colors.textSoft,
    );
  }
}

/// Petit indicateur de chargement à placer dans un bouton pendant une action.
class PremiumButtonProgress extends StatelessWidget {
  const PremiumButtonProgress({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: IconTheme.of(context).color ??
            DefaultTextStyle.of(context).style.color,
      ),
    );
  }
}

/// Mise en page « en-tête + liste » qui reste utilisable quelle que soit la
/// hauteur disponible (portrait, paysage, clavier ouvert) :
/// - s'il y a la place, l'en-tête s'affiche entièrement au-dessus de la liste ;
/// - sinon il est limité à une part de la hauteur et devient défilable,
///   la liste conservant toujours l'espace restant.
/// Évite les débordements des écrans `Column(en-tête…, Expanded(liste))`.
class AdaptiveHeaderLayout extends StatelessWidget {
  const AdaptiveHeaderLayout({
    super.key,
    required this.header,
    required this.body,
    this.maxHeaderFraction = 0.45,
    this.spacing = 12,
  });

  final List<Widget> header;
  final Widget body;
  final double maxHeaderFraction;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeader = constraints.maxHeight.isFinite
            ? constraints.maxHeight * maxHeaderFraction
            : double.infinity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeader),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: header,
                ),
              ),
            ),
            SizedBox(height: spacing),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class PremiumMetricTile extends StatelessWidget {
  const PremiumMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Si fourni, la tuile devient cliquable (navigation ou action).
  /// Laissé nul, la tuile reste purement informative comme avant.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;

    final decoration = BoxDecoration(
      color: colors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(
        color: colors.border,
        width: 1.1,
      ),
    );

    final content = Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.petrolSoft,
              borderRadius: BorderRadius.circular(AppRadius.iconAvatar),
            ),
            child: Icon(
              icon,
              color: colors.petrol,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.petrol,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      );

    if (onTap == null) {
      return Container(
        width: 165,
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Ink(
          width: 165,
          padding: const EdgeInsets.all(16),
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}

class PremiumStatusBadge extends StatelessWidget {
  const PremiumStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor, width: 1.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: foregroundColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: foregroundColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumActionRow extends StatelessWidget {
  const PremiumActionRow({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children,
    );
  }
}

class PremiumInfoLine extends StatelessWidget {
  const PremiumInfoLine({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final safeValue = value.trim().isEmpty ? '-' : value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          safeValue,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSoft,
              ),
        ),
      ],
    );
  }
}

/// Matrice de conversion en niveaux de gris (luminance), pour un filigrane
/// neutre quelle que soit la palette.
const List<double> _grayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

class PremiumWatermarkBackground extends StatelessWidget {
  const PremiumWatermarkBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Logo de la marque en filigrane : en nuances de gris et de blanc,
        // très estompé (presque invisible), non-cliquable, centré par-dessus
        // le fond des pages.
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.035,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 360,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Variante « drop-in » d'un `Column(children: [en-tête…, Expanded(liste)])` :
/// mêmes enfants, mais l'en-tête (tout sauf le dernier enfant, qui doit être
/// un `Expanded`/`Flexible`) devient défilable et plafonné à une part de la
/// hauteur quand la place manque (paysage, clavier ouvert, petit écran).
/// Quand la place suffit, le rendu est identique à un `Column` classique.
class AdaptiveHeaderColumn extends StatelessWidget {
  const AdaptiveHeaderColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.maxHeaderFraction = 0.45,
  }) : assert(children.length > 0);

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final double maxHeaderFraction;

  @override
  Widget build(BuildContext context) {
    final body = children.last;
    assert(
      body is Flexible,
      'AdaptiveHeaderColumn : le dernier enfant doit être Expanded/Flexible.',
    );
    final header = children.sublist(0, children.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeader = constraints.maxHeight.isFinite
            ? constraints.maxHeight * maxHeaderFraction
            : double.infinity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeader),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: header,
                  ),
                ),
              ),
            body,
          ],
        );
      },
    );
  }
}

/// Pastille rouge indiquant un nombre d'éléments non lus (« 99+ » au-delà).
class UnreadBubble extends StatelessWidget {
  const UnreadBubble({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final text = count > 99 ? '99+' : '$count';
    return Semantics(
      label: '$count non lu${count > 1 ? 's' : ''}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
