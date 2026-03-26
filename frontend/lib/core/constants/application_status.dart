import 'package:flutter/material.dart';

class AppStatusConfig {
  final String key;
  final String labelFr;
  final String labelEn;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const AppStatusConfig({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
}

class ApplicationStatuses {
  static const all = [
    saved, applied, onlineAssessment, phoneScreen,
    technical, finalInterview, offer, accepted, rejected, ghosted, withdrawn,
  ];

  static const saved = AppStatusConfig(
    key: 'saved',
    labelFr: 'Sauvegardée',
    labelEn: 'Saved',
    textColor: Color(0xFF475569),
    bgColor: Color(0xFFF1F5F9),
    borderColor: Color(0xFFCBD5E1),
  );

  static const applied = AppStatusConfig(
    key: 'applied',
    labelFr: 'Postulée',
    labelEn: 'Applied',
    textColor: Color(0xFF085041),
    bgColor: Color(0xFFE1F5EE),
    borderColor: Color(0xFF5DCAA5),
  );

  static const onlineAssessment = AppStatusConfig(
    key: 'online_assessment',
    labelFr: 'Test en ligne',
    labelEn: 'Online test',
    textColor: Color(0xFF0C447C),
    bgColor: Color(0xFFE6F1FB),
    borderColor: Color(0xFF85B7EB),
  );

  static const phoneScreen = AppStatusConfig(
    key: 'phone_screen',
    labelFr: 'Entretien tél.',
    labelEn: 'Phone screen',
    textColor: Color(0xFF3C3489),
    bgColor: Color(0xFFEEEDFE),
    borderColor: Color(0xFFAFA9EC),
  );

  static const technical = AppStatusConfig(
    key: 'technical',
    labelFr: 'Entretien tech.',
    labelEn: 'Technical',
    textColor: Color(0xFF72243E),
    bgColor: Color(0xFFFBEAF0),
    borderColor: Color(0xFFED93B1),
  );

  static const finalInterview = AppStatusConfig(
    key: 'final_interview',
    labelFr: 'Entretien final',
    labelEn: 'Final interview',
    textColor: Color(0xFF633806),
    bgColor: Color(0xFFFAEEDA),
    borderColor: Color(0xFFFAC775),
  );

  static const offer = AppStatusConfig(
    key: 'offer',
    labelFr: 'Offre reçue',
    labelEn: 'Offer received',
    textColor: Color(0xFF27500A),
    bgColor: Color(0xFFEAF3DE),
    borderColor: Color(0xFF97C459),
  );

  static const accepted = AppStatusConfig(
    key: 'accepted',
    labelFr: 'Acceptée',
    labelEn: 'Accepted',
    textColor: Color(0xFF04342C),
    bgColor: Color(0xFF9FE1CB),
    borderColor: Color(0xFF5DCAA5),
  );

  static const rejected = AppStatusConfig(
    key: 'rejected',
    labelFr: 'Rejetée',
    labelEn: 'Rejected',
    textColor: Color(0xFF791F1F),
    bgColor: Color(0xFFFCEBEB),
    borderColor: Color(0xFFF09595),
  );

  static const ghosted = AppStatusConfig(
    key: 'ghosted',
    labelFr: 'Sans réponse',
    labelEn: 'Ghosted',
    textColor: Color(0xFF5C5470),
    bgColor: Color(0xFFF0EDF5),
    borderColor: Color(0xFFB8B0C9),
  );

  static const withdrawn = AppStatusConfig(
    key: 'withdrawn',
    labelFr: 'Retirée',
    labelEn: 'Withdrawn',
    textColor: Color(0xFF444441),
    bgColor: Color(0xFFF1EFE8),
    borderColor: Color(0xFFB4B2A9),
  );

  static AppStatusConfig fromKey(String key) {
    return all.firstWhere(
      (s) => s.key == key,
      orElse: () => saved,
    );
  }
}
