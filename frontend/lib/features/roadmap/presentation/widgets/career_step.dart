import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form_decorations.dart';

class CareerStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String level;
  final TextEditingController yearsController;
  final TextEditingController previousFieldController;
  final ValueChanged<String> onLevelChanged;

  const CareerStep({
    super.key,
    required this.formKey,
    required this.level,
    required this.yearsController,
    required this.previousFieldController,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 8.h),
          Text(t.t('onboarding.step_career_title'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),
          DropdownButtonFormField<String>(
            initialValue: level,
            decoration: dropdownDecoration(
              context,
              label: t.t('onboarding.level'),
              icon: Icons.trending_up_rounded,
            ),
            items: [
              DropdownMenuItem(
                  value: 'junior',
                  child: Text(t.t('onboarding.level_junior'))),
              DropdownMenuItem(
                  value: 'mid', child: Text(t.t('onboarding.level_mid'))),
              DropdownMenuItem(
                  value: 'senior',
                  child: Text(t.t('onboarding.level_senior'))),
              DropdownMenuItem(
                  value: 'reconversion',
                  child: Text(t.t('onboarding.level_reconversion'))),
            ],
            onChanged: (v) => onLevelChanged(v!),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: yearsController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration(
              context,
              label: t.t('onboarding.years_experience'),
              icon: Icons.work_history_outlined,
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 0 || n > 50) {
                return t.t('onboarding.invalid_years');
              }
              return null;
            },
          ),
          if (level == 'reconversion') ...[
            SizedBox(height: 16.h),
            TextFormField(
              controller: previousFieldController,
              decoration: inputDecoration(
                context,
                label: t.t('onboarding.previous_field'),
                icon: Icons.swap_horiz_rounded,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? t.t('onboarding.required_field')
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
