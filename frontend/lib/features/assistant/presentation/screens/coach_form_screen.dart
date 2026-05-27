import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/settings/presentation/providers/preferences_provider.dart';
import 'package:frontend/core/utils/job_title_validator.dart';

class CoachFormScreen extends ConsumerStatefulWidget {
  const CoachFormScreen({super.key});

  @override
  ConsumerState<CoachFormScreen> createState() => _CoachFormScreenState();
}

class _CoachFormScreenState extends ConsumerState<CoachFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  PlatformFile? _cvFile;
  late String _language;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _language = ref.read(preferencesProvider).resolveAiLanguage('fr');
    // Reset le state d'analyse quand on arrive sur le formulaire
    Future.microtask(() => ref.read(coachAnalysisProvider.notifier).reset());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _descriptionController.clear();
    _jobTitleController.clear();
    _companyController.clear();
    setState(() {
      _cvFile = null;
      _language = ref.read(preferencesProvider).resolveAiLanguage('fr');
    });
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _cvFile = result.files.first);
    }
  }

  Future<void> _analyze() async {
    if (!_formKey.currentState!.validate() || _cvFile?.path == null) return;
    final t = AppLocalizations.of(context);

    setState(() => _isAnalyzing = true);
    ref.read(coachAnalysisProvider.notifier).reset();

    try {
      // Naviguer vers l'écran résultat qui observe le stream
      context.push('/assistant/coach/result');

      // Lancer l'analyse, la boucle SSE vit dans le notifier
      await ref.read(coachAnalysisProvider.notifier).analyze(
        cvPath: _cvFile!.path!,
        jobDescription: _descriptionController.text.trim(),
        jobTitle: _jobTitleController.text.trim().isEmpty ? null : _jobTitleController.text.trim(),
        companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        language: _language,
      );
      // Reset le formulaire seulement si l'analyse a abouti
      if (mounted && ref.read(coachAnalysisProvider).status == 'done') {
        _resetForm();
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('429')) {
        AppSnackbar.error(context, t.t('assistant.limit_reached'));
      } else {
        AppSnackbar.error(context, t.t('assistant.analyze_error'));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final usageAsync = ref.watch(coachUsageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('assistant.coach_title'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          children: [
            // Usage restant
            usageAsync.when(
              data: (usage) {
                final remaining = usage['remaining'] as int? ?? 0;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: remaining > 0
                        ? cs.primary.withValues(alpha: 0.08)
                        : cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        remaining > 0 ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                        size: 18.sp,
                        color: remaining > 0 ? cs.primary : cs.error,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        t.t('assistant.remaining_analyses').replaceAll('{count}', '$remaining'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: remaining > 0 ? cs.primary : cs.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            SizedBox(height: 20.h),

            // Upload CV
            _label(t.t('assistant.cv_label'), cs),
            SizedBox(height: 6.h),
            GestureDetector(
              onTap: _pickCv,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _cvFile != null
                        ? cs.primary.withValues(alpha: 0.5)
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  color: _cvFile != null ? cs.primary.withValues(alpha: 0.06) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _cvFile != null ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                      size: 22.sp,
                      color: _cvFile != null ? cs.primary : cs.onSurfaceVariant,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _cvFile?.name ?? t.t('assistant.cv_pick'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: _cvFile != null ? FontWeight.w600 : FontWeight.w400,
                          color: _cvFile != null ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_cvFile != null)
                      GestureDetector(
                        onTap: () => setState(() => _cvFile = null),
                        child: Icon(Icons.close_rounded, size: 18.sp, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Description de l'offre
            _label(t.t('assistant.job_desc_label'), cs),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              textInputAction: TextInputAction.next,
              decoration: _deco(t.t('assistant.job_desc_hint'), cs),
              validator: (v) => v == null || v.trim().isEmpty ? t.t('assistant.job_desc_required') : null,
            ),
            SizedBox(height: 16.h),

            // Titre du poste
            _label(t.t('assistant.job_title_label'), cs),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _jobTitleController,
              textInputAction: TextInputAction.next,
              decoration: _deco(t.t('assistant.job_title_hint'), cs),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return t.t('assistant.job_title_required');
                return validateJobTitleField(v.trim(), t);
              },
            ),
            SizedBox(height: 16.h),

            // Nom entreprise (optionnel)
            _label(t.t('assistant.company_label'), cs),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _companyController,
              textInputAction: TextInputAction.done,
              decoration: _deco(t.t('assistant.company_hint'), cs),
            ),
            SizedBox(height: 16.h),

            // Langue
            _label(t.t('assistant.language_label'), cs),
            SizedBox(height: 6.h),
            DropdownButtonFormField<String>(
              initialValue: _language,
              onTap: () => FocusScope.of(context).unfocus(),
              decoration: _deco('', cs),
              items: [
                DropdownMenuItem(value: 'fr', child: Text(t.t('onboarding.language_fr'))),
                DropdownMenuItem(value: 'en', child: Text(t.t('onboarding.language_en'))),
              ],
              onChanged: (v) {
                setState(() => _language = v!);
                ref.read(preferencesProvider.notifier).setAiLanguage(v!);
              },
            ),
            SizedBox(height: 24.h),

            // Bouton analyser
            FilledButton(
              onPressed: _cvFile != null && !_isAnalyzing ? _analyze : null,
              style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 48.h)),
              child: _isAnalyzing
                  ? SizedBox(width: 20.w, height: 20.w, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : Text(t.t('assistant.analyze_button')),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ColorScheme cs) {
    return Text(text, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface));
  }

  InputDecoration _deco(String hint, ColorScheme cs) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.primary, width: 1.5)),
    );
  }
}
