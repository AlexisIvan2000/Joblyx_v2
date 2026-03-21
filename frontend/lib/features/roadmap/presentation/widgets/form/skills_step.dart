import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_fields.dart';

// Réexporte SkillChipData pour que les imports existants continuent de fonctionner
export 'package:frontend/features/roadmap/presentation/widgets/form/form_fields.dart'
    show SkillChipData;

/// Étape 3 du formulaire IA : sélection des compétences.
class SkillsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<SkillChipData> selectedSkills;
  final List<String> allSkillNames;
  final bool isUploadingCv;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onUploadCv;
  final ValueChanged<String> onAddSkill;
  final ValueChanged<SkillChipData> onRemoveSkill;
  final ValueChanged<SkillChipData> onShowProficiencyPicker;

  const SkillsStep({
    super.key,
    required this.formKey,
    required this.selectedSkills,
    required this.allSkillNames,
    required this.isUploadingCv,
    required this.searchController,
    required this.searchFocusNode,
    required this.onUploadCv,
    required this.onAddSkill,
    required this.onRemoveSkill,
    required this.onShowProficiencyPicker,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 8.h),
          Text(t.t('onboarding.step_skills_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 16.h),

          // Bouton d'upload du CV pour extraction automatique des compétences
          CvUploadButton(isUploading: isUploadingCv, onUpload: onUploadCv),
          SizedBox(height: 4.h),
          Text(
            t.t('onboarding.upload_cv_sub'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),

          // Séparateur "ou ajouter manuellement"
          _Divider(cs: cs),
          SizedBox(height: 16.h),

          // Champ de recherche et d'ajout de compétences
          SkillSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            allSkillNames: allSkillNames,
            selectedSkills: selectedSkills,
            onSelected: onAddSkill,
          ),
          SizedBox(height: 20.h),

          // Affichage des compétences sélectionnées ou message vide
          if (selectedSkills.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text(t.t('onboarding.no_skills_yet'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: selectedSkills
                  .map((skill) => SkillChipWidget(
                        skill: skill,
                        onDelete: () => onRemoveSkill(skill),
                        onTap: () => onShowProficiencyPicker(skill),
                      ))
                  .toList(),
            ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

/// Séparateur horizontal avec texte "ou ajouter manuellement".
class _Divider extends StatelessWidget {
  final ColorScheme cs;
  const _Divider({required this.cs});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            t.t('onboarding.or_add_manually'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}
