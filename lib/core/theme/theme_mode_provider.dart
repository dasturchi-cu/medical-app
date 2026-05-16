import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_theme_mode';

/// Foydalanuvchi tanlovi: yorug‘ / qorong‘u / tizim (Telegram uslubi).
enum AppThemePreference {
  light,
  dark,
  system;

  static AppThemePreference fromStorage(String? raw) {
    switch (raw) {
      case 'dark':
        return AppThemePreference.dark;
      case 'system':
        return AppThemePreference.system;
      case 'light':
      default:
        return AppThemePreference.light;
    }
  }

  String toStorage() {
    switch (this) {
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.system:
        return 'system';
      case AppThemePreference.light:
        return 'light';
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
    }
  }
}

/// Ilova ishga tushishidan oldin yuklash (flicker kamaytirish).
Future<AppThemePreference> loadThemePreferenceEarly() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return AppThemePreference.fromStorage(prefs.getString(_prefsKey));
  } catch (_) {
    return AppThemePreference.system;
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemePreference>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<AppThemePreference> {
  AppThemePreference? _bootstrapped;

  void bootstrap(AppThemePreference pref) {
    _bootstrapped = pref;
  }

  @override
  Future<AppThemePreference> build() async {
    if (_bootstrapped != null) {
      final v = _bootstrapped!;
      _bootstrapped = null;
      return v;
    }
    return loadThemePreferenceEarly();
  }

  Future<void> setPreference(AppThemePreference pref) async {
    state = AsyncData(pref);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, pref.toStorage());
    } catch (_) {}
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? AppThemePreference.system;
    final next = switch (current) {
      AppThemePreference.light => AppThemePreference.dark,
      AppThemePreference.dark => AppThemePreference.system,
      AppThemePreference.system => AppThemePreference.light,
    };
    await setPreference(next);
  }
}
