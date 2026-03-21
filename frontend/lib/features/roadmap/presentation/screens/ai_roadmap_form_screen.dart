import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/onboarding/data/skills_loader.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/career_step.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/goals_step.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form/skills_step.dart';

class AIRoadmapFormScreen extends ConsumerStatefulWidget {
  const AIRoadmapFormScreen({super.key});

  @override
  ConsumerState<AIRoadmapFormScreen> createState() =>
      _AIRoadmapFormScreenState();
}

class _AIRoadmapFormScreenState extends ConsumerState<AIRoadmapFormScreen> {
  final _mapboxService = MapboxService();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1
  String _level = 'junior';
  final _yearsController = TextEditingController(text: '0');
  final _previousFieldController = TextEditingController();

  // Step 2
  final List<TextEditingController> _jobControllers = [
    TextEditingController()
  ];
  final _locationController = TextEditingController();
  String _city = '';
  String _province = '';
  String _language = 'fr';
  List<MapboxPlace> _locationSuggestions = [];
  bool _showLocationSuggestions = false;
  final _locationFieldKey = GlobalKey();

  // Step 3
  Map<String, List<String>> _skillsData = {};
  List<String> _allSkillNames = [];
  final List<SkillChipData> _selectedSkills = [];
  bool _isUploadingCv = false;
  final _skillSearchController = TextEditingController();
  final _skillSearchFocusNode = FocusNode();

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>()
  ];

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final data = await SkillsLoader.load();
    if (!mounted) return;
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
      final jobs =
          _jobControllers.where((c) => c.text.trim().isNotEmpty).toList();
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
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

      if (!mounted) return;
      context.go('/roadmap');

      final notifier = ref.read(roadmapProvider.notifier);
      await for (final event in notifier.generateWithAI(
        level: _level,
        yearsExperience: int.tryParse(_yearsController.text) ?? 0,
        targetJobs: targetJobs,
        city: _city,
        province: _province,
        language: _language,
        previousField: _level == 'reconversion'
            ? _previousFieldController.text.trim()
            : null,
        skills: skills,
      )) {
        final eventType = event['event'] as String;
        if (eventType == 'error') break;
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t('onboarding.error'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // CV upload 

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
      final svc = ref.read(roadmapServiceProvider);
      final extracted = await svc.extractSkills(file.path!);
      if (!mounted) return;

      int added = 0;
      for (final s in extracted) {
        final name = s['skill_name'] as String;
        final alreadyExists =
            _selectedSkills.any((c) => c.skillName == name);
        if (!alreadyExists) {
          _selectedSkills.add(SkillChipData(
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

  void _addSkillManually(String skillName) {
    String? category;
    for (final entry in _skillsData.entries) {
      if (entry.value.contains(skillName)) {
        category = entry.key;
        break;
      }
    }
    if (category == null) return;
    if (_selectedSkills.any((c) => c.skillName == skillName)) return;

    setState(() {
      _selectedSkills.add(SkillChipData(
        skillName: skillName,
        category: category!,
        proficiency: 'intermediate',
      ));
      _skillSearchController.clear();
    });
  }

  // Location

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

  void _showProficiencyPicker(SkillChipData skill) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(skill.skillName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              for (final level in ['beginner', 'intermediate', 'advanced'])
                ListTile(
                  leading: Icon(
                    skill.proficiency == level
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: cs.primary,
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
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              )
            : null,
        title: Text(t.t('dashboard.generate')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  CareerStep(
                    formKey: _formKeys[0],
                    level: _level,
                    yearsController: _yearsController,
                    previousFieldController: _previousFieldController,
                    onLevelChanged: (v) => setState(() => _level = v),
                  ),
                  GoalsStep(
                    formKey: _formKeys[1],
                    jobControllers: _jobControllers,
                    locationController: _locationController,
                    city: _city,
                    language: _language,
                    locationSuggestions: _locationSuggestions,
                    showLocationSuggestions: _showLocationSuggestions,
                    locationFieldKey: _locationFieldKey,
                    onAddJob: () => setState(
                        () => _jobControllers.add(TextEditingController())),
                    onRemoveJob: (i) => setState(() {
                      _jobControllers[i].dispose();
                      _jobControllers.removeAt(i);
                    }),
                    onLocationChanged: _onLocationChanged,
                    onSelectLocation: _selectLocation,
                    onClearLocation: () => setState(() {
                      _locationController.clear();
                      _city = '';
                      _province = '';
                      _locationSuggestions = [];
                      _showLocationSuggestions = false;
                    }),
                    onLanguageChanged: (v) =>
                        setState(() => _language = v),
                  ),
                  SkillsStep(
                    formKey: _formKeys[2],
                    selectedSkills: _selectedSkills,
                    allSkillNames: _allSkillNames,
                    isUploadingCv: _isUploadingCv,
                    searchController: _skillSearchController,
                    searchFocusNode: _skillSearchFocusNode,
                    onUploadCv: _uploadCv,
                    onAddSkill: _addSkillManually,
                    onRemoveSkill: (s) =>
                        setState(() => _selectedSkills.remove(s)),
                    onShowProficiencyPicker: _showProficiencyPicker,
                  ),
                ],
              ),
            ),
            // Dots
            Padding(
              padding: EdgeInsets.only(top: 8.h),
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
                      color: isActive
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
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
                          : t.t('dashboard.generate')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
