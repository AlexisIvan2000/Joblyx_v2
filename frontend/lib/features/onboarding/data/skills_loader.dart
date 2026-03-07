import 'dart:convert';
import 'package:flutter/services.dart';

/// Charge et fournit les compétences depuis skills.json
class SkillsLoader {
  static Map<String, List<String>>? _cache;

  /// Retourne une map {catégorie: [noms de skills]}
  static Future<Map<String, List<String>>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/data/skills.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final it = json['IT'] as Map<String, dynamic>;

    final result = <String, List<String>>{};
    for (final entry in it.entries) {
      final skills = (entry.value as List)
          .map((s) => s['name'] as String)
          .toList();
      result[entry.key] = skills;
    }

    _cache = result;
    return result;
  }

  /// Liste des catégories disponibles
  static Future<List<String>> categories() async {
    final data = await load();
    return data.keys.toList();
  }

  /// Liste des skills pour une catégorie donnée
  static Future<List<String>> skillsFor(String category) async {
    final data = await load();
    return data[category] ?? [];
  }
}
