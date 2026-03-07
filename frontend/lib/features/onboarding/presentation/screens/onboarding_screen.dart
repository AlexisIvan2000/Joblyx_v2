import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/onboarding/data/onboarding_service.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/onboarding/data/skills_loader.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _onboardingService = OnboardingService();
  final _mapboxService = MapboxService();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 — Carrière
  String _level = 'junior';
  final _yearsController = TextEditingController(text: '0');
  final _previousFieldController = TextEditingController();

  // Step 2 — Objectifs & localisation
  final List<TextEditingController> _jobControllers = [TextEditingController()];
  final _locationController = TextEditingController();
  String _city = '';
  String _province = '';
  String _language = 'fr';
  List<MapboxPlace> _locationSuggestions = [];
  bool _showLocationSuggestions = false;
  final _locationFieldKey = GlobalKey();

  // Step 3 — Compétences
  Map<String, List<String>> _skillsData = {};
  List<String> _allSkillNames = [];
  final List<_SkillChip> _selectedSkills = [];
  bool _isUploadingCv = false;
  final _skillSearchController = TextEditingController();
  final _skillSearchFocusNode = FocusNode();

  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final data = await SkillsLoader.load();
    if (!mounted) return;
    // Construire la liste plate de tous les skills avec leur catégorie
    final allNames = <String>[];
    for (final skills in data.values) {
      allNames.addAll(skills);
    }
    setState(() {
      _skillsData = data;
      _allSkillNames = allNames;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _yearsController.dispose();
    _previousFieldController.dispose();
    _locationController.dispose();
    _mapboxService.dispose();
    _skillSearchController.dispose();
    _skillSearchFocusNode.dispose();
    for (final c in _jobControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;

    final t = AppLocalizations.of(context);
    if (_currentStep == 1) {
      final jobs = _jobControllers.where((c) => c.text.trim().isNotEmpty).toList();
      if (jobs.isEmpty) {
        AppSnackbar.error(context, t.t('onboarding.at_least_one_job'));
        return;
      }
      if (_city.isEmpty) {
        AppSnackbar.error(context, t.t('onboarding.required_field'));
        return;
      }
    }
    if (_currentStep == 2) {
      if (_selectedSkills.isEmpty) {
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

      final skills = _selectedSkills
          .map((s) => {
                'skill_name': s.skillName,
                'category': s.category,
                'proficiency': s.proficiency,
              })
          .toList();

      await _onboardingService.complete(
        level: _level,
        yearsExperience: int.tryParse(_yearsController.text) ?? 0,
        targetJobs: targetJobs,
        city: _city,
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

  // ─── Upload CV ──────────────────────────────────────────────────
  Future<void> _uploadCv() async {
    final t = AppLocalizations.of(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploadingCv = true);

    try {
      final extracted = await _onboardingService.extractSkills(file.path!);
      if (!mounted) return;

      // Ajouter les skills extraits (éviter les doublons)
      int added = 0;
      for (final s in extracted) {
        final name = s['skill_name'] as String;
        final alreadyExists = _selectedSkills.any((c) => c.skillName == name);
        if (!alreadyExists) {
          _selectedSkills.add(_SkillChip(
            skillName: name,
            category: s['category'] as String,
            proficiency: s['proficiency'] as String? ?? 'intermediate',
          ));
          added++;
        }
      }

      setState(() {});
      if (!mounted) return;
      AppSnackbar.success(
        context,
        t.t('onboarding.skills_extracted').replaceAll('{count}', '$added'),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t('onboarding.upload_cv_error'));
    } finally {
      if (mounted) setState(() => _isUploadingCv = false);
    }
  }

  // ─── Ajout manuel d'un skill ────────────────────────────────────
  void _addSkillManually(String skillName) {
    // Trouver la catégorie du skill
    String? category;
    for (final entry in _skillsData.entries) {
      if (entry.value.contains(skillName)) {
        category = entry.key;
        break;
      }
    }
    if (category == null) return;

    // Éviter les doublons
    if (_selectedSkills.any((c) => c.skillName == skillName)) return;

    setState(() {
      _selectedSkills.add(_SkillChip(
        skillName: skillName,
        category: category!,
        proficiency: 'intermediate',
      ));
      _skillSearchController.clear();
    });
  }

  // ─── Localisation ──────────────────────────────────────────────
  Future<void> _onLocationChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _locationSuggestions = [];
        _showLocationSuggestions = false;
      });
      return;
    }

    final results = await _mapboxService.searchPlaces(query);
    if (!mounted) return;
    setState(() {
      _locationSuggestions = results;
      _showLocationSuggestions = results.isNotEmpty;
    });
    if (results.isNotEmpty) {
      _scrollToWidget(_locationFieldKey);
    }
  }

  void _selectLocation(MapboxPlace place) {
    setState(() {
      _city = place.city;
      _province = place.province;
      _locationController.text = place.fullName;
      _locationSuggestions = [];
      _showLocationSuggestions = false;
    });
  }

  /// Scrolle pour rendre visible le widget associé à la clé
  void _scrollToWidget(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
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
          // Localisation via Mapbox
          Column(
            key: _locationFieldKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _locationController,
                decoration: _inputDecoration(
                  label: t.t('onboarding.location'),
                  icon: Icons.location_on_outlined,
                ).copyWith(
                  hintText: t.t('onboarding.location_hint'),
                  suffixIcon: _city.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 20.sp),
                          onPressed: () {
                            setState(() {
                              _locationController.clear();
                              _city = '';
                              _province = '';
                              _locationSuggestions = [];
                              _showLocationSuggestions = false;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: _onLocationChanged,
                onTap: () => _scrollToWidget(_locationFieldKey),
              ),
              if (_showLocationSuggestions)
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
                      children: _locationSuggestions.map((place) {
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.location_on_outlined, size: 20.sp, color: cs.primary),
                          title: Text(place.city, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                          subtitle: Text(place.fullName, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                          onTap: () => _selectLocation(place),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
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
          SizedBox(height: 16.h),

          // ── Bouton Upload CV ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingCv ? null : _uploadCv,
              icon: _isUploadingCv
                  ? SizedBox(
                      width: 18.sp, height: 18.sp,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    )
                  : Icon(Icons.upload_file_rounded, size: 22.sp),
              label: Text(
                _isUploadingCv
                    ? t.t('onboarding.uploading_cv')
                    : t.t('onboarding.upload_cv'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 52.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            t.t('onboarding.upload_cv_sub'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 20.h),
          // ── Séparateur ──
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text(
                  t.t('onboarding.or_add_manually'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          SizedBox(height: 16.h),

          // ── Recherche autocomplete ──
          LayoutBuilder(
            builder: (context, constraints) {
              return RawAutocomplete<String>(
                textEditingController: _skillSearchController,
                focusNode: _skillSearchFocusNode,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable.empty();
                  final query = textEditingValue.text.toLowerCase();
                  // Filtrer les skills déjà sélectionnés
                  final selected = _selectedSkills.map((s) => s.skillName).toSet();
                  return _allSkillNames
                      .where((s) => s.toLowerCase().contains(query) && !selected.contains(s));
                },
                onSelected: _addSkillManually,
                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration: _inputDecoration(
                      label: t.t('onboarding.search_skill'),
                      icon: Icons.search_rounded,
                    ),
                    onFieldSubmitted: (_) => onFieldSubmitted(),
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                          );
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
          ),

          SizedBox(height: 20.h),

          // ── Liste de chips ──
          if (_selectedSkills.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text(
                  t.t('onboarding.no_skills_yet'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _selectedSkills.map((skill) {
                return _buildSkillChipWidget(skill, t, cs);
              }).toList(),
            ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildSkillChipWidget(_SkillChip skill, AppLocalizations t, ColorScheme cs) {
    // Couleur selon le niveau
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
      avatar: CircleAvatar(
        radius: 5.r,
        backgroundColor: chipColor,
      ),
      deleteIcon: Icon(Icons.close_rounded, size: 16.sp),
      onDeleted: () => setState(() => _selectedSkills.remove(skill)),
      onPressed: () => _showProficiencyPicker(skill),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
    );
  }

  void _showProficiencyPicker(_SkillChip skill) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  skill.skillName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final level in ['beginner', 'intermediate', 'advanced'])
                ListTile(
                  leading: Icon(
                    skill.proficiency == level ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(t.t('onboarding.prof_$level')),
                  onTap: () {
                    setState(() => skill.proficiency = level);
                    Navigator.pop(ctx);
                  },
                ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              )
            : null,
        title: Text(t.t('onboarding.title')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicateur de progression (dots)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    width: isActive ? 24.w : 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: isActive ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4.r),
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
            // Bouton en bas — "Suivant" sur les 2 premières étapes, "Compléter" sur la dernière
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: SizedBox(
                width: double.infinity,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip {
  final String skillName;
  final String category;
  String proficiency;

  _SkillChip({
    required this.skillName,
    required this.category,
    this.proficiency = 'intermediate',
  });
}
