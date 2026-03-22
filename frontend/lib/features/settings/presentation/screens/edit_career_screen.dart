import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/onboarding/data/skills_loader.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_decorations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/form_fields.dart';

/// Nombre maximum de postes cibles autorisés.
const _maxTargetJobs = 3;

class EditCareerScreen extends ConsumerStatefulWidget {
  const EditCareerScreen({super.key});

  @override
  ConsumerState<EditCareerScreen> createState() => _EditCareerScreenState();
}

class _EditCareerScreenState extends ConsumerState<EditCareerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapboxService = MapboxService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCv = false;
  String _streamingText = '';

  // Champs carrière
  String _level = 'junior';
  final _yearsController = TextEditingController(text: '0');
  final _previousFieldController = TextEditingController();
  final List<TextEditingController> _jobControllers = [TextEditingController()];
  final _locationController = TextEditingController();
  String _city = '';
  String _province = '';
  String _language = 'fr';
  List<MapboxPlace> _locationSuggestions = [];
  bool _showLocationSuggestions = false;
  final _locationFieldKey = GlobalKey();

  // Compétences
  Map<String, List<String>> _skillsData = {};
  List<String> _allSkillNames = [];
  final List<SkillChipData> _selectedSkills = [];
  final _skillSearchController = TextEditingController();
  final _skillSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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

  // ── Chargement des données ──────────────────────────────────

  Future<void> _loadData() async {
    final skillsData = await SkillsLoader.load();
    final allNames = skillsData.values.expand((s) => s).toList();

    Map<String, dynamic>? career;
    try {
      career = await ref.read(roadmapServiceProvider).getCareerProfile();
    } catch (_) {
      // 404 = pas de profil, formulaire vide
    }

    if (!mounted) return;
    setState(() {
      _skillsData = skillsData;
      _allSkillNames = allNames;
      if (career != null) _populateFromCareer(career);
      _isLoading = false;
    });
  }

  /// Pré-remplit les champs depuis les données existantes du profil.
  void _populateFromCareer(Map<String, dynamic> career) {
    _level = career['level'] as String? ?? 'junior';
    _yearsController.text = '${career['years_experience'] ?? 0}';
    _previousFieldController.text = career['previous_field'] as String? ?? '';
    _language = career['language'] as String? ?? 'fr';
    _city = career['city'] as String? ?? '';
    _province = career['province'] as String? ?? '';
    _locationController.text = _city.isNotEmpty ? '$_city, $_province' : '';

    final jobs = (career['target_jobs'] as List?)?.cast<String>() ?? [];
    _jobControllers.clear();
    for (final job in jobs.isEmpty ? [''] : jobs) {
      _jobControllers.add(TextEditingController(text: job));
    }

    _selectedSkills.clear();
    for (final s in (career['skills'] as List?) ?? []) {
      _selectedSkills.add(SkillChipData(
        skillName: s['skill_name'] as String,
        category: s['category'] as String,
        proficiency: s['proficiency'] as String? ?? 'intermediate',
      ));
    }
  }

  // ── Sauvegarde ──────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t = AppLocalizations.of(context);

    final targetJobs = _jobControllers.map((c) => c.text.trim()).where((j) => j.isNotEmpty).toList();
    if (targetJobs.isEmpty) return AppSnackbar.error(context, t.t('onboarding.at_least_one_job'));
    if (_city.isEmpty) return AppSnackbar.error(context, t.t('onboarding.required_field'));
    if (_selectedSkills.isEmpty) return AppSnackbar.error(context, t.t('onboarding.at_least_one_skill'));

    setState(() => _isSaving = true);
    try {
      await ref.read(roadmapServiceProvider).updateCareerProfile({
        'level': _level,
        'years_experience': int.tryParse(_yearsController.text) ?? 0,
        'target_jobs': targetJobs,
        'city': _city,
        'province': _province,
        'language': _language,
        if (_level == 'reconversion') 'previous_field': _previousFieldController.text.trim(),
        'skills': _selectedSkills.map((s) => {
          'skill_name': s.skillName, 'category': s.category, 'proficiency': s.proficiency,
        }).toList(),
      });
      if (!mounted) return;
      AppSnackbar.success(context, t.t('profile_screen.career_saved'));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, t.t('profile_screen.career_save_error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Localisation ────────────────────────────────────────────

  Future<void> _onLocationChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() { _locationSuggestions = []; _showLocationSuggestions = false; });
      return;
    }
    final results = await _mapboxService.searchPlaces(query);
    if (!mounted) return;
    setState(() { _locationSuggestions = results; _showLocationSuggestions = results.isNotEmpty; });
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

  void _clearLocation() {
    setState(() { _locationController.clear(); _city = ''; _province = ''; _locationSuggestions = []; _showLocationSuggestions = false; });
  }

  // ── Compétences ─────────────────────────────────────────────

  Future<void> _uploadCv() async {
    final t = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    setState(() { _isUploadingCv = true; _streamingText = ''; });
    try {
      final svc = ref.read(roadmapServiceProvider);
      int added = 0;

      await for (final event in svc.extractSkillsStream(result.files.first.path!)) {
        if (!mounted) return;
        final eventType = event['event'] as String;
        final data = event['data'] as Map<String, dynamic>;

        if (eventType == 'chunk') {
          setState(() => _streamingText += (data['text'] as String? ?? ''));
        } else if (eventType == 'skills') {
          final skills = (data['skills'] as List?) ?? [];
          for (final s in skills) {
            final skill = s as Map<String, dynamic>;
            final name = skill['skill_name'] as String;
            if (!_selectedSkills.any((c) => c.skillName == name)) {
              _selectedSkills.add(SkillChipData(
                skillName: name, category: skill['category'] as String,
                proficiency: skill['proficiency'] as String? ?? 'intermediate',
              ));
              added++;
            }
          }
          setState(() {});
        } else if (eventType == 'error') {
          if (mounted) AppSnackbar.error(context, t.t('onboarding.upload_cv_error'));
          break;
        }
      }
      if (!mounted) return;
      if (added > 0) {
        AppSnackbar.success(context, t.t('onboarding.skills_extracted').replaceAll('{count}', '$added'));
      }
    } catch (_) {
      if (mounted) AppSnackbar.error(context, t.t('onboarding.upload_cv_error'));
    } finally {
      if (mounted) setState(() { _isUploadingCv = false; _streamingText = ''; });
    }
  }

  void _addSkillManually(String skillName) {
    final category = _skillsData.entries
        .where((e) => e.value.contains(skillName))
        .map((e) => e.key)
        .firstOrNull;
    if (category == null || _selectedSkills.any((c) => c.skillName == skillName)) return;
    setState(() {
      _selectedSkills.add(SkillChipData(skillName: skillName, category: category, proficiency: 'intermediate'));
      _skillSearchController.clear();
    });
  }

  void _showProficiencyPicker(SkillChipData skill) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(skill.skillName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            for (final level in ['beginner', 'intermediate', 'advanced'])
              ListTile(
                leading: Icon(
                  skill.proficiency == level ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: cs.primary,
                ),
                title: Text(t.t('onboarding.prof_$level')),
                onTap: () { setState(() => skill.proficiency = level); Navigator.pop(ctx); },
              ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('profile_screen.career_profile')),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(width: 20.sp, height: 20.sp,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary))
                  : Text(t.t('settings.save'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  children: [
                    ..._buildCareerSection(t, cs),
                    SizedBox(height: 28.h),
                    ..._buildGoalsSection(t, cs),
                    SizedBox(height: 28.h),
                    ..._buildSkillsSection(t, cs),
                    SizedBox(height: 80.h),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Sections du formulaire ──────────────────────────────────

  List<Widget> _buildCareerSection(AppLocalizations t, ColorScheme cs) => [
    _SectionTitle(title: t.t('onboarding.step_career_title')),
    SizedBox(height: 12.h),
    DropdownButtonFormField<String>(
      initialValue: _level,
      decoration: dropdownDecoration(context, label: t.t('onboarding.level'), icon: Icons.trending_up_rounded),
      items: ['junior', 'mid', 'senior', 'reconversion']
          .map((v) => DropdownMenuItem(value: v, child: Text(t.t('onboarding.level_$v'))))
          .toList(),
      onChanged: (v) => setState(() => _level = v!),
    ),
    SizedBox(height: 14.h),
    TextFormField(
      controller: _yearsController,
      keyboardType: TextInputType.number,
      decoration: inputDecoration(context, label: t.t('onboarding.years_experience'), icon: Icons.work_history_outlined),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return (n == null || n < 0 || n > 50) ? t.t('onboarding.invalid_years') : null;
      },
    ),
    if (_level == 'reconversion') ...[
      SizedBox(height: 14.h),
      TextFormField(
        controller: _previousFieldController,
        decoration: inputDecoration(context, label: t.t('onboarding.previous_field'), icon: Icons.swap_horiz_rounded),
      ),
    ],
  ];

  List<Widget> _buildGoalsSection(AppLocalizations t, ColorScheme cs) => [
    _SectionTitle(title: t.t('onboarding.step_goals_title')),
    SizedBox(height: 12.h),
    ...List.generate(_jobControllers.length, (i) => Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(children: [
        Expanded(child: TextFormField(
          controller: _jobControllers[i],
          decoration: inputDecoration(context, label: '${t.t('onboarding.target_job')} ${i + 1}', icon: Icons.work_outline_rounded),
        )),
        if (_jobControllers.length > 1)
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: cs.error, size: 22.sp),
            onPressed: () => setState(() { _jobControllers[i].dispose(); _jobControllers.removeAt(i); }),
          ),
      ]),
    )),
    if (_jobControllers.length < _maxTargetJobs)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _jobControllers.add(TextEditingController())),
          icon: Icon(Icons.add_rounded, size: 20.sp),
          label: Text(t.t('onboarding.add_job')),
        ),
      ),
    SizedBox(height: 12.h),
    LocationField(
      fieldKey: _locationFieldKey, controller: _locationController, city: _city,
      suggestions: _locationSuggestions, showSuggestions: _showLocationSuggestions,
      onChanged: _onLocationChanged, onSelect: _selectLocation, onClear: _clearLocation,
    ),
    SizedBox(height: 14.h),
    DropdownButtonFormField<String>(
      initialValue: _language,
      decoration: dropdownDecoration(context, label: t.t('onboarding.language'), icon: Icons.language_rounded),
      items: ['fr', 'en', 'bilingual']
          .map((v) => DropdownMenuItem(value: v, child: Text(t.t('onboarding.language_$v'))))
          .toList(),
      onChanged: (v) => setState(() => _language = v!),
    ),
  ];

  List<Widget> _buildSkillsSection(AppLocalizations t, ColorScheme cs) => [
    _SectionTitle(title: t.t('onboarding.step_skills_title')),
    SizedBox(height: 12.h),
    CvUploadButton(isUploading: _isUploadingCv, onUpload: _uploadCv),
    if (_streamingText.isNotEmpty) ...[
      SizedBox(height: 8.h),
      Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: 120.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: Text(
            _streamingText,
            style: TextStyle(
              fontSize: 11.sp,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ),
    ],
    SizedBox(height: 16.h),
    SkillSearchField(
      controller: _skillSearchController, focusNode: _skillSearchFocusNode,
      allSkillNames: _allSkillNames, selectedSkills: _selectedSkills, onSelected: _addSkillManually,
    ),
    SizedBox(height: 16.h),
    if (_selectedSkills.isEmpty)
      Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Text(t.t('onboarding.no_skills_yet'), style: TextStyle(color: cs.onSurfaceVariant)),
      ))
    else
      Wrap(
        spacing: 8.w, runSpacing: 8.h,
        children: _selectedSkills.map((skill) => SkillChipWidget(
          skill: skill,
          onDelete: () => setState(() => _selectedSkills.remove(skill)),
          onTap: () => _showProficiencyPicker(skill),
        )).toList(),
      ),
  ];
}

/// Titre de section dans le formulaire.
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }
}
