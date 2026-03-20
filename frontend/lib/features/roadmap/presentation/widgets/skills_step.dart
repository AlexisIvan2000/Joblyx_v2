import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form_decorations.dart';

class SkillChipData {
  final String skillName;
  final String category;
  String proficiency;

  SkillChipData({
    required this.skillName,
    required this.category,
    this.proficiency = 'intermediate',
  });
}

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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 16.h),
          _CvUploadButton(
              isUploading: isUploadingCv, onUpload: onUploadCv, cs: cs, t: t),
          SizedBox(height: 4.h),
          Text(
            t.t('onboarding.upload_cv_sub'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          _Divider(t: t, cs: cs),
          SizedBox(height: 16.h),
          _SkillSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            allSkillNames: allSkillNames,
            selectedSkills: selectedSkills,
            onSelected: onAddSkill,
          ),
          SizedBox(height: 20.h),
          if (selectedSkills.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text(
                  t.t('onboarding.no_skills_yet'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: selectedSkills
                  .map((skill) => _SkillChipWidget(
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

class _CvUploadButton extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onUpload;
  final ColorScheme cs;
  final AppLocalizations t;

  const _CvUploadButton({
    required this.isUploading,
    required this.onUpload,
    required this.cs,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isUploading ? null : onUpload,
        icon: isUploading
            ? SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.primary),
              )
            : Icon(Icons.upload_file_rounded, size: 22.sp),
        label: Text(isUploading
            ? t.t('onboarding.uploading_cv')
            : t.t('onboarding.upload_cv')),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 52.h),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r)),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppLocalizations t;
  final ColorScheme cs;
  const _Divider({required this.t, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            t.t('onboarding.or_add_manually'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

class _SkillSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> allSkillNames;
  final List<SkillChipData> selectedSkills;
  final ValueChanged<String> onSelected;

  const _SkillSearchField({
    required this.controller,
    required this.focusNode,
    required this.allSkillNames,
    required this.selectedSkills,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable.empty();
            final query = textEditingValue.text.toLowerCase();
            final selected = selectedSkills.map((s) => s.skillName).toSet();
            return allSkillNames.where(
                (s) => s.toLowerCase().contains(query) && !selected.contains(s));
          },
          onSelected: onSelected,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: inputDecoration(
                context,
                label: t.t('onboarding.search_skill'),
                icon: Icons.search_rounded,
              ),
              onFieldSubmitted: (_) => onFieldSubmitted(),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Scrollable.ensureVisible(context,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignmentPolicy:
                            ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
                  }
                });
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12.r),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200.h,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title:
                            Text(option, style: TextStyle(fontSize: 13.sp)),
                        tileColor: cs.surfaceContainerHighest,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SkillChipWidget extends StatelessWidget {
  final SkillChipData skill;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SkillChipWidget({
    required this.skill,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final Color chipColor;
    final String levelLabel;
    switch (skill.proficiency) {
      case 'beginner':
        chipColor = Colors.orange;
        levelLabel = t.t('onboarding.prof_beginner');
      case 'advanced':
        chipColor = Colors.green;
        levelLabel = t.t('onboarding.prof_advanced');
      default:
        chipColor = cs.primary;
        levelLabel = t.t('onboarding.prof_intermediate');
    }

    return InputChip(
      label: Text('${skill.skillName}  ·  $levelLabel'),
      labelStyle: TextStyle(fontSize: 12.sp, color: cs.onSurface),
      avatar: CircleAvatar(radius: 5.r, backgroundColor: chipColor),
      deleteIcon: Icon(Icons.close_rounded, size: 16.sp),
      onDeleted: onDelete,
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
    );
  }
}
