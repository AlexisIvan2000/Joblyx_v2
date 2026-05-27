import 'package:frontend/core/l10n/app_localizations.dart';

/// Caractères autorisés dans un titre de poste.
final _allowedPattern = RegExp(
  r'^[\w\s\-./()&+,#àâäéèêëïîôùûüçÀÂÄÉÈÊËÏÎÔÙÛÜÇ]+$',
  unicode: true,
);

/// Mots-clés IT au moins un doit être présent.
const _itKeywords = {
  'developer', 'développeur', 'développeuse', 'dev', 'programmer', 'programmeur',
  'software', 'logiciel', 'fullstack', 'full-stack', 'full stack',
  'frontend', 'front-end', 'front end', 'backend', 'back-end', 'back end',
  'mobile', 'web', 'api', 'microservices',
  'engineer', 'ingénieur', 'ingénieure', 'engineering',
  'sre', 'site reliability', 'platform',
  'data', 'database', 'données', 'analytics', 'analyst', 'analyste',
  'machine learning', 'ml', 'deep learning', 'ai', 'ia',
  'data scientist', 'data engineer', 'data analyst',
  'bi', 'business intelligence', 'etl', 'pipeline',
  'cloud', 'aws', 'azure', 'gcp', 'devops', 'devsecops',
  'infrastructure', 'infra', 'sysadmin', 'système', 'systems',
  'network', 'réseau', 'linux', 'kubernetes', 'docker', 'terraform',
  'security', 'sécurité', 'cybersecurity', 'cybersécurité',
  'pentest', 'pentester', 'soc',
  'qa', 'quality', 'qualité', 'test', 'testing', 'automation', 'sdet',
  'architect', 'architecte', 'architecture',
  'tech lead', 'team lead', 'lead', 'principal',
  'cto', 'manager', 'gestionnaire',
  'embedded', 'embarqué', 'firmware', 'iot',
  'blockchain', 'game', 'jeux', 'unity', 'unreal',
  'ux', 'ui', 'design', 'designer', 'product',
  'scrum', 'agile', 'project', 'projet',
  'support', 'helpdesk', 'help desk', 'it support',
  'erp', 'sap', 'salesforce', 'crm',
  'it', 'tic', 'informatique', 'numérique', 'digital', 'tech', 'technicien',
  'consultant', 'consulting',
};


String? validateJobTitleField(String value, AppLocalizations t) {
  if (value.length > 100) return t.t('onboarding.job_too_long');
  if (!_allowedPattern.hasMatch(value)) return t.t('onboarding.job_invalid_chars');
  final lower = value.toLowerCase();
  if (!_itKeywords.any((kw) => lower.contains(kw))) {
    return t.t('onboarding.job_not_it');
  }
  return null;
}
