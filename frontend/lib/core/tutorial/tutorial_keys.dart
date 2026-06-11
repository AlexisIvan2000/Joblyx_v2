import 'package:flutter/widgets.dart';

/// Clés globales pour cibler les éléments du tour guidé.
/// Partagées entre le shell (onglets) et le dashboard (cartes).
class TutorialKeys {
  TutorialKeys._();
  static final instance = TutorialKeys._();

  final navHome = GlobalKey();
  final navRoadmap = GlobalKey();
  final navApplications = GlobalKey();
  final navAssistant = GlobalKey();
  final navProfile = GlobalKey();

  final statsCard = GlobalKey();
  final roadmapCard = GlobalKey();
  final currentPhase = GlobalKey();
}
