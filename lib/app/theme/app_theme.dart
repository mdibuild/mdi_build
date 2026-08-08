import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_font.dart';
import 'app_palette.dart';
import 'app_palette_colors.dart';

class AppTheme {
  static ThemeData build(
    AppPalette palette,
    int accentIndex, {
    int? titleColorIndex,
    int? textColorIndex,
    String? fontId,
  }) {
    final colors = resolvePaletteColors(
      palette,
      accentIndex,
      titleColorIndex: titleColorIndex,
      textColorIndex: textColorIndex,
    );
    final isDark = palette.brightness == Brightness.dark;
    final onAccent = isDark ? Colors.black : Colors.white;

    final fontOption = resolveFontOption(fontId ?? defaultAppFontId);
    TextStyle f(TextStyle style) =>
        GoogleFonts.getFont(fontOption.googleFontFamily, textStyle: style);

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

    final styledTextTheme = base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: colors.title,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.title,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: colors.bodyText,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textSoft,
        height: 1.35,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
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
        titleTextStyle: f(
          TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: onAccent,
            letterSpacing: -0.2,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: colors.border,
            width: 1.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.petrol,
          foregroundColor: onAccent,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: f(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 1;
            if (states.contains(WidgetState.hovered)) return 3;
            return 0;
          }),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.2),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.petrolSoft,
          foregroundColor: colors.petrol,
          elevation: 0,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: colors.petrol.withValues(alpha: 0.35)),
          ),
          textStyle: f(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 1;
            if (states.contains(WidgetState.hovered)) return 3;
            return 0;
          }),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.petrol,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: BorderSide(
            color: colors.petrol,
            width: 1.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: f(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            colors.petrol.withValues(alpha: 0.06),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: f(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textSoft,
          ),
        ),
        hintStyle: f(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textSoft,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: colors.border,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: colors.border,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: colors.petrol,
            width: 1.6,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        selectedColor: colors.petrolSoft,
        disabledColor: colors.surfaceAlt,
        side: BorderSide(
          color: colors.border,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: f(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
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
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
