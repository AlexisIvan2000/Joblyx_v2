import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/onboarding/data/mapbox_service.dart';
import 'package:frontend/features/onboarding/data/skills_loader.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/form_decorations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/skills_step.dart';

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

  // Career fields
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

  // Skills
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

  Future<void> _loadData() async {
    final skillsData = await SkillsLoader.load();
    final allNames = <String>[];
    for (final skills in skillsData.values) {
      allNames.addAll(skills);
    }

    Map<String, dynamic>? career;
    try {
      final svc = ref.read(roadmapServiceProvider);
      career = await svc.getCareerProfile();
    } catch (_) {
      // 404 = no career yet, show empty form
    }

    if (!mounted) return;
    setState(() {
      _skillsData = skillsData;
      _allSkillNames = allNames;

      if (career != null) {
        _level = career['level'] as String? ?? 'junior';
        _yearsController.text = '${career['years_experience'] ?? 0}';
        _previousFieldController.text = career['previous_field'] as String? ?? '';
        _language = career['language'] as String? ?? 'fr';
        _city = career['city'] as String? ?? '';
        _province = career['province'] as String? ?? '';
        _locationController.text = _city.isNotEmpty ? '$_city, $_province' : '';

        final jobs = (career['target_jobs'] as List?)?.cast<String>() ?? [];
        _jobControllers.clear();
        if (jobs.isEmpty) {
          _jobControllers.add(TextEditingController());
        } else {
          for (final job in jobs) {
            _jobControllers.add(TextEditingController(text: job));
          }
        }

        final skills = (career['skills'] as List?) ?? [];
        _selectedSkills.clear();
        for (final s in skills) {
          _selectedSkills.add(SkillChipData(
            skillName: s['skill_name'] as String,
            category: s['category'] as String,
            proficiency: s['proficiency'] as String? ?? 'intermediate',
          ));
        }
      }

      _isLoading = false;
    });
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final t = AppLocalizations.of(context);
    final targetJobs = _jobControllers
        .map((c) => c.text.trim())
        .where((j) => j.isNotEmpty)
        .toList();

    if (targetJobs.isEmpty) {
      AppSnackbar.error(context, t.t('onboarding.at_least_one_job'));
      return;
    }
    if (_city.isEmpty) {
      AppSnackbar.error(context, t.t('onboarding.required_field'));
      return;
    }
    if (_selectedSkills.isEmpty) {
      AppSnackbar.error(context, t.t('onboarding.at_least_one_skill'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final svc = ref.read(roadmapServiceProvider);
      await svc.updateCareerProfile({
        'level': _level,
        'years_experience': int.tryParse(_yearsController.text) ?? 0,
        'target_jobs': targetJobs,
        'city': _city,
        'province': _province,
        'language': _language,
        if (_level == 'reconversion') 'previous_field': _previousFieldController.text.trim(),
        'skills': _selectedSkills
            .map((s) => {
                  'skill_name': s.skillName,
                  'category': s.category,
                  'proficiency': s.proficiency,
                })
            .toList(),
      });
      if (!mounted) return;
      AppSnackbar.success(context, t.t('profile_screen.career_saved'));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t('profile_screen.career_save_error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  // Skills

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
        if (!_selectedSkills.any((c) => c.skillName == name)) {
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
        title: Text(t.t('profile_screen.career_profile')),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 20.sp,
                      height: 20.sp,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
                    )
                  : Text(t.t('settings.save'),
                      style: TextStyle(fontWeight: FontWeight.w700)),
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
                    // ── Niveau & expérience ──
                    _SectionTitle(title: t.t('onboarding.step_career_title')),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: _level,
                      decoration: dropdownDecoration(
                        context,
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
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: _yearsController,
                      keyboardType: TextInputType.number,
                      decoration: inputDecoration(
                        context,
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
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _previousFieldController,
                        decoration: inputDecoration(
                          context,
                          label: t.t('onboarding.previous_field'),
                          icon: Icons.swap_horiz_rounded,
                        ),
                      ),
                    ],

                    SizedBox(height: 28.h),

                    // ── Objectifs ──
                    _SectionTitle(title: t.t('onboarding.step_goals_title')),
                    SizedBox(height: 12.h),
                    ...List.generate(_jobControllers.length, (i) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _jobControllers[i],
                                decoration: inputDecoration(
                                  context,
                                  label: '${t.t('onboarding.target_job')} ${i + 1}',
                                  icon: Icons.work_outline_rounded,
                                ),
                              ),
                            ),
                            if (_jobControllers.length > 1)
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: cs.error, size: 22.sp),
                                onPressed: () => setState(() {
                                  _jobControllers[i].dispose();
                                  _jobControllers.removeAt(i);
                                }),
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
                    // Location
                    _LocationField(
                      fieldKey: _locationFieldKey,
                      controller: _locationController,
                      city: _city,
                      suggestions: _locationSuggestions,
                      showSuggestions: _showLocationSuggestions,
                      onChanged: _onLocationChanged,
                      onSelect: _selectLocation,
                      onClear: () => setState(() {
                        _locationController.clear();
                        _city = '';
                        _province = '';
                        _locationSuggestions = [];
                        _showLocationSuggestions = false;
                      }),
                    ),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: dropdownDecoration(
                        context,
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

                    SizedBox(height: 28.h),

                    // ── Compétences ──
                    _SectionTitle(title: t.t('onboarding.step_skills_title')),
                    SizedBox(height: 12.h),
                    _CvUploadButton(isUploading: _isUploadingCv, onUpload: _uploadCv, cs: cs, t: t),
                    SizedBox(height: 16.h),
                    _SkillSearchField(
                      controller: _skillSearchController,
                      focusNode: _skillSearchFocusNode,
                      allSkillNames: _allSkillNames,
                      selectedSkills: _selectedSkills,
                      onSelected: _addSkillManually,
                    ),
                    SizedBox(height: 16.h),
                    if (_selectedSkills.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Text(t.t('onboarding.no_skills_yet'),
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _selectedSkills
                            .map((skill) => _SkillChip(
                                  skill: skill,
                                  onDelete: () => setState(() => _selectedSkills.remove(skill)),
                                  onTap: () => _showProficiencyPicker(skill),
                                ))
                            .toList(),
                      ),
                    SizedBox(height: 80.h),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
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
                    leading: Icon(Icons.location_on_outlined, size: 20.sp, color: cs.primary),
                    title: Text(place.city, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text(place.fullName, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              )
            : Icon(Icons.upload_file_rounded, size: 22.sp),
        label: Text(isUploading ? t.t('onboarding.uploading_cv') : t.t('onboarding.upload_cv')),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 52.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
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
            return allSkillNames.where((s) => s.toLowerCase().contains(query) && !selected.contains(s));
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
                  constraints: BoxConstraints(maxHeight: 200.h, maxWidth: constraints.maxWidth),
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

class _SkillChip extends StatelessWidget {
  final SkillChipData skill;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SkillChip({required this.skill, required this.onDelete, required this.onTap});

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
