import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clés de stockage
const _keyLocale = 'app_locale';
const _keyTheme = 'app_theme';
const _keyAiLanguage = 'ai_language';

/// État des préférences utilisateur (langue + thème).
class AppPreferences {
  final String? localeCode; // null = système, 'fr', 'en'
  final ThemeMode themeMode;
  final String? aiLanguage; // null = suit la langue de l'app, 'fr', 'en'

  const AppPreferences({this.localeCode, this.themeMode = ThemeMode.system, this.aiLanguage});

  /// Locale résolue : si null, utilise la locale du système.
  Locale? get locale => localeCode != null ? Locale(localeCode!) : null;

  /// Langue IA résolue : si null, suit la langue de l'app.
  String resolveAiLanguage(String appLocale) => aiLanguage ?? localeCode ?? appLocale;
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
    final aiLanguage = prefs.getString(_keyAiLanguage);

    final themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    state = AppPreferences(localeCode: localeCode, themeMode: themeMode, aiLanguage: aiLanguage);
  }

  /// Change la langue de l'app et sauvegarde dans le cache.
  Future<void> setLocale(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (localeCode == null) {
      await prefs.remove(_keyLocale);
    } else {
      await prefs.setString(_keyLocale, localeCode);
    }
    state = AppPreferences(localeCode: localeCode, themeMode: state.themeMode, aiLanguage: state.aiLanguage);
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
    state = AppPreferences(localeCode: state.localeCode, themeMode: mode, aiLanguage: state.aiLanguage);
  }

  /// Change la langue IA et sauvegarde dans le cache.
  Future<void> setAiLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiLanguage, language);
    state = AppPreferences(localeCode: state.localeCode, themeMode: state.themeMode, aiLanguage: language);
  }
}
