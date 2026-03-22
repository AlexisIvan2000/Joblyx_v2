import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/settings/presentation/providers/preferences_provider.dart';

void main() {
  group('AppPreferences', () {
    test('locale est null par défaut (= système)', () {
      const prefs = AppPreferences();
      expect(prefs.localeCode, isNull);
      expect(prefs.locale, isNull);
    });

    test('locale retourne un Locale quand défini', () {
      const prefs = AppPreferences(localeCode: 'fr');
      expect(prefs.locale, const Locale('fr'));
    });

    test('themeMode est system par défaut', () {
      const prefs = AppPreferences();
      expect(prefs.themeMode, ThemeMode.system);
    });
  });

  group('PreferencesNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setLocale met à jour le state et sauvegarde', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.notifier).setLocale('fr');
      final prefs = container.read(preferencesProvider);
      expect(prefs.localeCode, 'fr');
      expect(prefs.locale, const Locale('fr'));

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_locale'), 'fr');
    });

    test('setLocale null retire la préférence (retour au système)', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.notifier).setLocale(null);
      final prefs = container.read(preferencesProvider);
      expect(prefs.localeCode, isNull);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_locale'), isNull);
    });

    test('setThemeMode met à jour le state et sauvegarde', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.notifier).setThemeMode(ThemeMode.dark);
      final prefs = container.read(preferencesProvider);
      expect(prefs.themeMode, ThemeMode.dark);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_theme'), 'dark');
    });

    test('setThemeMode light sauvegarde "light"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.notifier).setThemeMode(ThemeMode.light);
      expect(container.read(preferencesProvider).themeMode, ThemeMode.light);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_theme'), 'light');
    });

    test('setThemeMode system sauvegarde "system"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(preferencesProvider.notifier).setThemeMode(ThemeMode.system);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_theme'), 'system');
    });
  });
}
