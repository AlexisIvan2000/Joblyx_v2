import 'package:flutter/services.dart';

/// Helpers centralisés pour le retour haptique.
class Haptic {
  Haptic._();

  /// Tap léger (dismiss, toggle, sélection de filtre)
  static void light() => HapticFeedback.lightImpact();

  /// Tap moyen (navigation, ouverture de dialog, action secondaire)
  static void medium() => HapticFeedback.mediumImpact();

  /// Tap fort (soumission de formulaire, suppression, action principale)
  static void heavy() => HapticFeedback.heavyImpact();

  /// Sélection (toggle checkbox, radio, switch, filtre)
  static void selection() => HapticFeedback.selectionClick();
}
