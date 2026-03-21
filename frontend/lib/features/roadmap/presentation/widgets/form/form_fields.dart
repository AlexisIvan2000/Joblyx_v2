import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_decorations.dart';

/// Modèle de données pour un chip de compétence sélectionné.
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


/// Bouton pour uploader un CV (PDF) via file picker.
class CvUploadButton extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onUpload;

  const CvUploadButton({
    super.key,
    required this.isUploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isUploading ? null : onUpload,
        icon: isUploading
            ? SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              )
            : Icon(Icons.upload_file_rounded, size: 22.sp),
        label: Text(isUploading
            ? t.t('onboarding.uploading_cv')
            : t.t('onboarding.upload_cv')),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 52.h),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}


/// Champ d'autocomplétion pour rechercher et ajouter des compétences.
class SkillSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> allSkillNames;
  final List<SkillChipData> selectedSkills;
  final ValueChanged<String> onSelected;

  const SkillSearchField({
    super.key,
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
          optionsBuilder: (value) {
            if (value.text.isEmpty) return const Iterable.empty();
            final query = value.text.toLowerCase();
            // Exclure les compétences déjà sélectionnées
            final selected = selectedSkills.map((s) => s.skillName).toSet();
            return allSkillNames.where(
              (s) => s.toLowerCase().contains(query) && !selected.contains(s),
            );
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: inputDecoration(
                context,
                label: t.t('onboarding.search_skill'),
                icon: Icons.search_rounded,
              ),
              onFieldSubmitted: (_) => onFieldSubmitted(),
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
                        title: Text(option, style: TextStyle(fontSize: 13.sp)),
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



/// Chip coloré affichant une compétence avec son niveau de maîtrise.
class SkillChipWidget extends StatelessWidget {
  final SkillChipData skill;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const SkillChipWidget({
    super.key,
    required this.skill,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    // Couleur et label selon le niveau de maîtrise
    final (Color chipColor, String levelLabel) = switch (skill.proficiency) {
      'beginner' => (Colors.orange, t.t('onboarding.prof_beginner')),
      'advanced' => (Colors.green, t.t('onboarding.prof_advanced')),
      _ => (cs.primary, t.t('onboarding.prof_intermediate')),
    };

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



/// Champ de localisation avec autocomplétion Mapbox.
class LocationField extends StatelessWidget {
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final String city;
  final List<MapboxPlace> suggestions;
  final bool showSuggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapboxPlace> onSelect;
  final VoidCallback onClear;

  const LocationField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.city,
    required this.suggestions,
    required this.showSuggestions,
    required this.onChanged,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: inputDecoration(
            context,
            label: t.t('onboarding.location'),
            icon: Icons.location_on_outlined,
          ).copyWith(
            hintText: t.t('onboarding.location_hint'),
            // Bouton de suppression affiché uniquement si une ville est saisie
            suffixIcon: city.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 20.sp),
                    onPressed: onClear,
                  )
                : null,
          ),
          onChanged: onChanged,
          onTap: () {
            // Faire défiler jusqu'au champ lors du focus pour éviter qu'il soit masqué
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = fieldKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(ctx,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
              }
            });
          },
        ),
        // Liste de suggestions Mapbox
        if (showSuggestions)
          Container(
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: suggestions.map((place) {
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on_outlined, size: 20.sp, color: cs.primary),
                    title: Text(place.city,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text(place.fullName,
                        style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    onTap: () => onSelect(place),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
