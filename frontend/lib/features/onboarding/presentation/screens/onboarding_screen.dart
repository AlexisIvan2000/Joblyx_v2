import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/onboarding/data/onboarding_service.dart';

const _provinces = {
  'AB': 'Alberta',
  'BC': 'British Columbia',
  'MB': 'Manitoba',
  'NB': 'New Brunswick',
  'NL': 'Newfoundland and Labrador',
  'NS': 'Nova Scotia',
  'NT': 'Northwest Territories',
  'NU': 'Nunavut',
  'ON': 'Ontario',
  'PE': 'Prince Edward Island',
  'QC': 'Quebec',
  'SK': 'Saskatchewan',
  'YT': 'Yukon',
};

const _categories = [
  'programming_languages',
  'backend_frameworks',
  'frontend_frameworks',
  'databases',
  'cloud_devops',
  'tools',
  'soft_skills',
  'other',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _onboardingService = OnboardingService();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 — Carrière
  String _level = 'junior';
  final _yearsController = TextEditingController(text: '0');
  final _previousFieldController = TextEditingController();

  // Step 2 — Objectifs & localisation
  final List<TextEditingController> _jobControllers = [TextEditingController()];
  final _cityController = TextEditingController();
  String _province = 'QC';
  String _language = 'fr';

  // Step 3 — Compétences
  final List<_SkillEntry> _skills = [_SkillEntry()];

  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];

  @override
  void dispose() {
    _pageController.dispose();
    _yearsController.dispose();
    _previousFieldController.dispose();
    _cityController.dispose();
    for (final c in _jobControllers) {
      c.dispose();
    }
    for (final s in _skills) {
      s.nameController.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;

    // Validations spécifiques
    final t = AppLocalizations.of(context);
    if (_currentStep == 1) {
      final jobs = _jobControllers.where((c) => c.text.trim().isNotEmpty).toList();
      if (jobs.isEmpty) {
        AppSnackbar.error(context, t.t('onboarding.at_least_one_job'));
        return;
      }
    }
    if (_currentStep == 2) {
      final validSkills = _skills.where((s) => s.nameController.text.trim().isNotEmpty).toList();
      if (validSkills.isEmpty) {
        AppSnackbar.error(context, t.t('onboarding.at_least_one_skill'));
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final t = AppLocalizations.of(context);

    try {
      final targetJobs = _jobControllers
          .map((c) => c.text.trim())
          .where((j) => j.isNotEmpty)
          .toList();

      final skills = _skills
          .where((s) => s.nameController.text.trim().isNotEmpty)
          .map((s) => {
                'skill_name': s.nameController.text.trim(),
                'category': s.category,
                'proficiency': s.proficiency,
              })
          .toList();

      await _onboardingService.complete(
        level: _level,
        yearsExperience: int.tryParse(_yearsController.text) ?? 0,
        targetJobs: targetJobs,
        city: _cityController.text.trim(),
        province: _province,
        language: _language,
        previousField: _level == 'reconversion' ? _previousFieldController.text.trim() : null,
        skills: skills,
      );

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t('onboarding.error'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20.sp) : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    );
  }

  InputDecoration _dropdownDecoration({required String label, IconData? icon}) {
    return _inputDecoration(label: label, icon: icon).copyWith(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
    );
  }

  // ─── Step 1 : Carrière ───────────────────────────────────────────
  Widget _buildStepCareer() {
    final t = AppLocalizations.of(context);
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 8.h),
          Text(t.t('onboarding.step_career_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),
          // Niveau
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: _dropdownDecoration(
              label: t.t('onboarding.level'),
              icon: Icons.trending_up_rounded,
            ),
            items: [
              DropdownMenuItem(value: 'junior', child: Text(t.t('onboarding.level_junior'))),
              DropdownMenuItem(value: 'mid', child: Text(t.t('onboarding.level_mid'))),
              DropdownMenuItem(value: 'senior', child: Text(t.t('onboarding.level_senior'))),
              DropdownMenuItem(value: 'reconversion', child: Text(t.t('onboarding.level_reconversion'))),
            ],
            onChanged: (v) => setState(() => _level = v!),
          ),
          SizedBox(height: 16.h),
          // Années d'expérience
          TextFormField(
            controller: _yearsController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              label: t.t('onboarding.years_experience'),
              icon: Icons.work_history_outlined,
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 0 || n > 50) return t.t('onboarding.invalid_years');
              return null;
            },
          ),
          // Ancien domaine (reconversion uniquement)
          if (_level == 'reconversion') ...[
            SizedBox(height: 16.h),
            TextFormField(
              controller: _previousFieldController,
              decoration: _inputDecoration(
                label: t.t('onboarding.previous_field'),
                icon: Icons.swap_horiz_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? t.t('onboarding.required_field') : null,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Step 2 : Objectifs & localisation ───────────────────────────
  Widget _buildStepGoals() {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 8.h),
          Text(t.t('onboarding.step_goals_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),
          // Emplois ciblés
          ...List.generate(_jobControllers.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _jobControllers[i],
                      decoration: _inputDecoration(
                        label: '${t.t('onboarding.target_job')} ${i + 1}',
                        icon: Icons.work_outline_rounded,
                      ),
                    ),
                  ),
                  if (_jobControllers.length > 1)
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: cs.error, size: 22.sp),
                      onPressed: () {
                        setState(() {
                          _jobControllers[i].dispose();
                          _jobControllers.removeAt(i);
                        });
                      },
                    ),
                ],
              ),
            );
          }),
          if (_jobControllers.length < 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _jobControllers.add(TextEditingController())),
                icon: Icon(Icons.add_rounded, size: 20.sp),
                label: Text(t.t('onboarding.add_job')),
              ),
            ),
          SizedBox(height: 12.h),
          // Ville
          TextFormField(
            controller: _cityController,
            decoration: _inputDecoration(
              label: t.t('onboarding.city'),
              icon: Icons.location_city_rounded,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.t('onboarding.required_field') : null,
          ),
          SizedBox(height: 16.h),
          // Province
          DropdownButtonFormField<String>(
            initialValue: _province,
            decoration: _dropdownDecoration(
              label: t.t('onboarding.province'),
              icon: Icons.map_outlined,
            ),
            items: _provinces.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _province = v!),
          ),
          SizedBox(height: 16.h),
          // Langue
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: _dropdownDecoration(
              label: t.t('onboarding.language'),
              icon: Icons.language_rounded,
            ),
            items: [
              DropdownMenuItem(value: 'fr', child: Text(t.t('onboarding.language_fr'))),
              DropdownMenuItem(value: 'en', child: Text(t.t('onboarding.language_en'))),
              DropdownMenuItem(value: 'bilingual', child: Text(t.t('onboarding.language_bilingual'))),
            ],
            onChanged: (v) => setState(() => _language = v!),
          ),
        ],
      ),
    );
  }

  // ─── Step 3 : Compétences ────────────────────────────────────────
  Widget _buildStepSkills() {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 8.h),
          Text(t.t('onboarding.step_skills_title'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 20.h),
          ...List.generate(_skills.length, (i) {
            final skill = _skills[i];
            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.t('onboarding.skill')} ${i + 1}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_skills.length > 1)
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: cs.error, size: 20.sp),
                            onPressed: () {
                              setState(() {
                                _skills[i].nameController.dispose();
                                _skills.removeAt(i);
                              });
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: skill.nameController,
                      decoration: _inputDecoration(
                        label: t.t('onboarding.skill_name'),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<String>(
                      initialValue: skill.category,
                      decoration: _dropdownDecoration(label: t.t('onboarding.skill_category')),
                      isExpanded: true,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(t.t('onboarding.cat_$c')),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => skill.category = v!),
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<String>(
                      initialValue: skill.proficiency,
                      decoration: _dropdownDecoration(label: t.t('onboarding.skill_proficiency')),
                      items: [
                        DropdownMenuItem(
                            value: 'beginner', child: Text(t.t('onboarding.prof_beginner'))),
                        DropdownMenuItem(
                            value: 'intermediate', child: Text(t.t('onboarding.prof_intermediate'))),
                        DropdownMenuItem(
                            value: 'advanced', child: Text(t.t('onboarding.prof_advanced'))),
                      ],
                      onChanged: (v) => setState(() => skill.proficiency = v!),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_skills.length < 10)
            TextButton.icon(
              onPressed: () => setState(() => _skills.add(_SkillEntry())),
              icon: Icon(Icons.add_rounded, size: 20.sp),
              label: Text(t.t('onboarding.add_skill')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    final stepLabels = [
      t.t('onboarding.step_career'),
      t.t('onboarding.step_goals'),
      t.t('onboarding.step_skills'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('onboarding.title')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicateur de progression
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              child: Row(
                children: List.generate(3, (i) {
                  final isActive = i <= _currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      child: Column(
                        children: [
                          Container(
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: isActive ? cs.primary : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            stepLabels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isActive ? cs.primary : cs.onSurfaceVariant,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Contenu des étapes
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepCareer(),
                  _buildStepGoals(),
                  _buildStepSkills(),
                ],
              ),
            ),
            // Navigation
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _prevStep,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, 50.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(t.t('onboarding.back')),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 12.w),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 1,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _nextStep,
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        textStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 22.sp,
                              height: 22.sp,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(_currentStep < 2
                              ? t.t('onboarding.next')
                              : t.t('onboarding.submit')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillEntry {
  final nameController = TextEditingController();
  String category = 'programming_languages';
  String proficiency = 'intermediate';
}
