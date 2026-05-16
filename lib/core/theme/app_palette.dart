import 'package:flutter/material.dart';

/// Telegram-style light/dark palette — barcha UI shu tokenlardan foydalanadi.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primary,
    required this.primaryText,
    required this.icon,
    required this.bottomBar,
    required this.bottomBarText,
    required this.bottomBarActive,
    required this.shadow,
    required this.error,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color primary;
  final Color primaryText;
  final Color icon;
  final Color bottomBar;
  final Color bottomBarText;
  final Color bottomBarActive;
  final Color shadow;
  final Color error;
  final Color success;

  /// Eski nomlar bilan moslik (`AppColors.surface` → `surface`).
  Color get surfaceAlt => surfaceSecondary;
  Color get bg => background;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF1F3F7),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    border: Color(0xFFE5E7EB),
    primary: Color(0xFF2563EB),
    primaryText: Color(0xFFFFFFFF),
    icon: Color(0xFF4B5563),
    bottomBar: Color(0xFFFFFFFF),
    bottomBarText: Color(0xFF6B7280),
    bottomBarActive: Color(0xFF2563EB),
    shadow: Color(0x1A000000),
    error: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0F141B),
    surface: Color(0xFF182231),
    surfaceSecondary: Color(0xFF111827),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFFD1D5DB),
    textMuted: Color(0xFF9CA3AF),
    border: Color(0xFF2A3441),
    primary: Color(0xFF3B82F6),
    primaryText: Color(0xFFFFFFFF),
    icon: Color(0xFFD1D5DB),
    bottomBar: Color(0xFF111827),
    bottomBarText: Color(0xFFD1D5DB),
    bottomBarActive: Color(0xFF60A5FA),
    shadow: Color(0x66000000),
    error: Color(0xFFF87171),
    success: Color(0xFF4ADE80),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? primary,
    Color? primaryText,
    Color? icon,
    Color? bottomBar,
    Color? bottomBarText,
    Color? bottomBarActive,
    Color? shadow,
    Color? error,
    Color? success,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryText: primaryText ?? this.primaryText,
      icon: icon ?? this.icon,
      bottomBar: bottomBar ?? this.bottomBar,
      bottomBarText: bottomBarText ?? this.bottomBarText,
      bottomBarActive: bottomBarActive ?? this.bottomBarActive,
      shadow: shadow ?? this.shadow,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceSecondary: l(surfaceSecondary, other.surfaceSecondary),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      primaryText: l(primaryText, other.primaryText),
      icon: l(icon, other.icon),
      bottomBar: l(bottomBar, other.bottomBar),
      bottomBarText: l(bottomBarText, other.bottomBarText),
      bottomBarActive: l(bottomBarActive, other.bottomBarActive),
      shadow: l(shadow, other.shadow),
      error: l(error, other.error),
      success: l(success, other.success),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}

/// Muted matn — ikkala rejimda o‘qiladi.
Color themedMutedText(BuildContext context) =>
    context.appColors.textSecondary;

Color themedIcon(BuildContext context) => context.appColors.icon;
