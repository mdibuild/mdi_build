import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_font.dart';
import 'app_palette.dart';
import 'app_palette_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData build(
    AppPalette palette,
    int accentIndex, {
    int? titleColorIndex,
    int? textColorIndex,
    int? highlightColorIndex,
    String? fontId,
  }) {
    final colors = resolvePaletteColors(
      palette,
      accentIndex,
      titleColorIndex: titleColorIndex,
      textColorIndex: textColorIndex,
      highlightColorIndex: highlightColorIndex,
    );
    final isDark = palette.brightness == Brightness.dark;
    final onAccent = isDark ? Colors.black : Colors.white;

    final fontOption = resolveFontOption(fontId ?? defaultAppFontId);
    TextStyle f(TextStyle style) =>
        GoogleFonts.getFont(fontOption.googleFontFamily, textStyle: style);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    const controlMinSize = Size(0, 48);
    const controlPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final buttonText = f(
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );

    final baseColorScheme = isDark
        ? ColorScheme.dark(
            primary: colors.petrol,
            onPrimary: onAccent,
            secondary: colors.petrolSoft,
            onSecondary: colors.petrol,
            surface: colors.surface,
            onSurface: colors.text,
            error: colors.danger,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: colors.petrol,
            onPrimary: onAccent,
            secondary: colors.petrolSoft,
            onSecondary: colors.petrol,
            surface: colors.surface,
            onSurface: colors.text,
            error: colors.danger,
            onError: Colors.white,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: baseColorScheme.copyWith(
        primaryContainer: colors.petrolSoft,
        onPrimaryContainer: colors.petrol,
        secondaryContainer: colors.petrolSoft,
        onSecondaryContainer: colors.petrol,
      ),
    );

    // Échelle typographique resserrée : titres nets, texte courant lisible,
    // informations secondaires plus discrètes.
    final styledTextTheme = base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colors.title,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.title,
      ),
      bodyLarge: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
        color: colors.bodyText,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.bodyText,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: colors.textSoft,
        height: 1.35,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );

    // Action principale : fond plein couleur de marque, bien visible.
    // États : désactivé grisé, appuyé/survolé avec voile, sans ombre lourde.
    final primaryButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.border;
        }
        return colors.petrol;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textSoft;
        }
        return onAccent;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textSoft;
        }
        return onAccent;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return onAccent.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return onAccent.withValues(alpha: 0.08);
        }
        return null;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) ||
            states.contains(WidgetState.pressed)) {
          return 0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 3;
        }
        return 1;
      }),
      shadowColor: WidgetStatePropertyAll(
        colors.petrol.withValues(alpha: 0.35),
      ),
      minimumSize: const WidgetStatePropertyAll(controlMinSize),
      padding: const WidgetStatePropertyAll(controlPadding),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(buttonText),
      iconSize: const WidgetStatePropertyAll(20),
    );

    // Action secondaire : contour couleur de marque sur fond de surface.
    final secondaryButtonStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(colors.surface),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textSoft;
        }
        return colors.petrol;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textSoft;
        }
        return colors.petrol;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: colors.border, width: 1.4);
        }
        return BorderSide(color: colors.petrol, width: 1.4);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colors.petrol.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colors.petrol.withValues(alpha: 0.07);
        }
        return null;
      }),
      minimumSize: const WidgetStatePropertyAll(controlMinSize),
      padding: const WidgetStatePropertyAll(controlPadding),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(buttonText),
      iconSize: const WidgetStatePropertyAll(20),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: BorderSide(color: colors.border, width: 1.1),
    );

    return base.copyWith(
      extensions: [colors],
      textTheme: GoogleFonts.getTextTheme(
        fontOption.googleFontFamily,
        styledTextTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.petrol,
        foregroundColor: onAccent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        titleTextStyle: f(
          TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: onAccent,
            letterSpacing: -0.1,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: secondaryButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.petrol,
          disabledForegroundColor: colors.textSoft,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.petrol,
        foregroundColor: onAccent,
        elevation: 3,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: f(
          TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: colors.textSoft,
          ),
        ),
        hintStyle: f(
          TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: colors.textSoft,
          ),
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colors.border.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.petrol, width: 1.8),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 1.4),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        selectedColor: colors.petrolSoft,
        disabledColor: colors.surfaceAlt,
        side: BorderSide(color: colors.border, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: f(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: f(
          TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: colors.title,
          ),
        ),
        contentTextStyle: f(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.bodyText,
            height: 1.4,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.petrol,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.petrol,
        linearTrackColor: colors.surfaceAlt,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.yellow,
        unselectedLabelColor: onAccent.withValues(alpha: 0.7),
        indicatorColor: colors.yellow,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: f(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        unselectedLabelStyle: f(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: colors.border,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.petrolSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          f(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.petrol : colors.textSoft,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.petrol,
        unselectedItemColor: colors.textSoft,
        selectedLabelStyle: f(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        unselectedLabelStyle: f(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.petrol,
        contentTextStyle: f(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onAccent,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    );
  }
}
