import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form_decorations.dart';

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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),
          ...List.generate(jobControllers.length, (i) {
            return Padding(
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
                  if (jobControllers.length > 1)
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: cs.error, size: 22.sp),
                      onPressed: () => onRemoveJob(i),
                    ),
                ],
              ),
            );
          }),
          if (jobControllers.length < 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddJob,
                icon: Icon(Icons.add_rounded, size: 20.sp),
                label: Text(t.t('onboarding.add_job')),
              ),
            ),
          SizedBox(height: 12.h),
          _LocationField(
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
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: dropdownDecoration(
              context,
              label: t.t('onboarding.language'),
              icon: Icons.language_rounded,
            ),
            items: [
              DropdownMenuItem(
                  value: 'fr', child: Text(t.t('onboarding.language_fr'))),
              DropdownMenuItem(
                  value: 'en', child: Text(t.t('onboarding.language_en'))),
              DropdownMenuItem(
                  value: 'bilingual',
                  child: Text(t.t('onboarding.language_bilingual'))),
            ],
            onChanged: (v) => onLanguageChanged(v!),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final String city;
  final List<MapboxPlace> suggestions;
  final bool showSuggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapboxPlace> onSelect;
  final VoidCallback onClear;

  const _LocationField({
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
            suffixIcon: city.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 20.sp),
                    onPressed: onClear,
                  )
                : null,
          ),
          onChanged: onChanged,
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = fieldKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(ctx,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
              }
            });
          },
        ),
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
                    leading: Icon(Icons.location_on_outlined,
                        size: 20.sp, color: cs.primary),
                    title: Text(place.city,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text(place.fullName,
                        style: TextStyle(
                            fontSize: 11.sp, color: cs.onSurfaceVariant)),
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
