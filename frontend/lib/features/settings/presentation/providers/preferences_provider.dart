import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clés de stockage
const _keyLocale = 'app_locale';
const _keyTheme = 'app_theme';

/// État des préférences utilisateur (langue + thème).
class AppPreferences {
  final String? localeCode; // null = système, 'fr', 'en'
  final ThemeMode themeMode;

  const AppPreferences({this.localeCode, this.themeMode = ThemeMode.system});

  /// Locale résolue : si null, utilise la locale du système.
  Locale? get locale => localeCode != null ? Locale(localeCode!) : null;
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);

class PreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    // Charge les préférences de manière asynchrone au démarrage
    Future.microtask(() => _load());
    return const AppPreferences();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final localeCode = prefs.getString(_keyLocale);
    final themeStr = prefs.getString(_keyTheme);

    final themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    state = AppPreferences(localeCode: localeCode, themeMode: themeMode);
  }

  /// Change la langue et sauvegarde dans le cache.
  Future<void> setLocale(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (localeCode == null) {
      await prefs.remove(_keyLocale);
    } else {
      await prefs.setString(_keyLocale, localeCode);
    }
    state = AppPreferences(localeCode: localeCode, themeMode: state.themeMode);
  }

  /// Change le thème et sauvegarde dans le cache.
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_keyTheme, value);
    state = AppPreferences(localeCode: state.localeCode, themeMode: mode);
  }
}
