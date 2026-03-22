import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_decorations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_fields.dart';

/// Nombre maximum de postes cibles autorisés.
const _maxTargetJobs = 3;

/// Étape 2 du formulaire IA : objectifs professionnels.
class GoalsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<TextEditingController> jobControllers;
  final TextEditingController locationController;
  final String city;
  final String language;
  final List<MapboxPlace> locationSuggestions;
  final bool showLocationSuggestions;
  final GlobalKey locationFieldKey;
  final VoidCallback onAddJob;
  final void Function(int) onRemoveJob;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<MapboxPlace> onSelectLocation;
  final VoidCallback onClearLocation;
  final ValueChanged<String> onLanguageChanged;

  const GoalsStep({
    super.key,
    required this.formKey,
    required this.jobControllers,
    required this.locationController,
    required this.city,
    required this.language,
    required this.locationSuggestions,
    required this.showLocationSuggestions,
    required this.locationFieldKey,
    required this.onAddJob,
    required this.onRemoveJob,
    required this.onLocationChanged,
    required this.onSelectLocation,
    required this.onClearLocation,
    required this.onLanguageChanged,
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
          Text(t.t('onboarding.step_goals_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),

          // Postes cibles (jusqu'à _maxTargetJobs)
          ...List.generate(jobControllers.length, (i) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: jobControllers[i],
                    decoration: inputDecoration(
                      context,
                      label: '${t.t('onboarding.target_job')} ${i + 1}',
                      icon: Icons.work_outline_rounded,
                    ),
                  ),
                ),
                // Bouton de suppression affiché uniquement s'il y a plusieurs postes
                if (jobControllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: cs.error, size: 22.sp),
                    onPressed: () => onRemoveJob(i),
                  ),
              ],
            ),
          )),
          // Bouton d'ajout de poste visible tant que le maximum n'est pas atteint
          if (jobControllers.length < _maxTargetJobs)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddJob,
                icon: Icon(Icons.add_rounded, size: 20.sp),
                label: Text(t.t('onboarding.add_job')),
              ),
            ),
          SizedBox(height: 12.h),

          // Champ de localisation avec autocomplétion Mapbox
          LocationField(
            fieldKey: locationFieldKey,
            controller: locationController,
            city: city,
            suggestions: locationSuggestions,
            showSuggestions: showLocationSuggestions,
            onChanged: onLocationChanged,
            onSelect: onSelectLocation,
            onClear: onClearLocation,
          ),
          SizedBox(height: 16.h),

          // Sélection de la langue de recherche d'emploi
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: dropdownDecoration(context, label: t.t('onboarding.language'), icon: Icons.language_rounded),
            items: ['fr', 'en', 'bilingual']
                .map((v) => DropdownMenuItem(value: v, child: Text(t.t('onboarding.language_$v'))))
                .toList(),
            onChanged: (v) => onLanguageChanged(v!),
          ),
          SizedBox(height: 6.h),
          Text(
            t.t('onboarding.language_hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
