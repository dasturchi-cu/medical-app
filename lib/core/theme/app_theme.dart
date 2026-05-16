import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'design_system.dart';

class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.primaryText,
      secondary: p.primary,
      onSecondary: p.primaryText,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      error: p.error,
      onError: p.primaryText,
      outline: p.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      dividerColor: p.border,
      extensions: [p],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        iconTheme: IconThemeData(color: p.icon),
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.border.withValues(alpha: 0.6)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.icon,
        textColor: p.textPrimary,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 13,
        ),
      ),
      iconTheme: IconThemeData(color: p.icon),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: p.textPrimary),
        bodyMedium: TextStyle(color: p.textPrimary),
        bodySmall: TextStyle(color: p.textSecondary),
        labelLarge: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: p.textSecondary),
        labelSmall: TextStyle(color: p.textMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bottomBar,
        indicatorColor: p.surfaceSecondary,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.bottomBarActive : p.bottomBarText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.bottomBarActive : p.bottomBarText,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bottomBar,
        selectedItemColor: p.bottomBarActive,
        unselectedItemColor: p.bottomBarText,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceSecondary,
        contentTextStyle: TextStyle(color: p.textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        textStyle: TextStyle(color: p.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: p.textPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primaryText;
          return p.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.border;
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          backgroundColor: p.primary,
          foregroundColor: p.primaryText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          side: BorderSide(color: p.border),
          foregroundColor: p.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        prefixIconColor: p.icon,
        suffixIconColor: p.icon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
        dividerColor: p.border,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );

    return base;
  }
}
