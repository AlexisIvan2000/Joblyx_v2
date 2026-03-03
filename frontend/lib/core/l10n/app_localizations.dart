import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Map<String, String> _strings;

  AppLocalizations(this._strings);

  static const supportedLocales = [
    Locale('en'),
    Locale('fr'),
  ];

  static Future<AppLocalizations> load(Locale locale) async {
    final code = locale.languageCode;
    final path = 'assets/i18n/$code.json';

    try {
      final jsonStr = await rootBundle.loadString(path);
      final Map<String, dynamic> map = json.decode(jsonStr);

      return AppLocalizations(_flattenMap(map));
    } catch (_) {
      return AppLocalizations({});
    }
  }

  String t(String key) => _strings[key] ?? key;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        ) ??
        AppLocalizations({});
  }
}

Map<String, String> _flattenMap(
  Map<String, dynamic> map, [
  String prefix = '',
]) {
  final result = <String, String>{};

  map.forEach((key, value) {
    final newKey = prefix.isEmpty ? key : '$prefix.$key';

    if (value is Map<String, dynamic>) {
      result.addAll(_flattenMap(value, newKey));
    } else {
      result[newKey] = value.toString();
    }
  });

  return result;
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale);

  @override
  bool shouldReload(_) => false;
}