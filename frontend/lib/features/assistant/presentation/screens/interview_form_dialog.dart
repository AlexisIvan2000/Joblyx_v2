import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/utils/job_title_validator.dart';

/// Dialog rapide pour démarrer un nouvel entretien.
/// Peut être pré-rempli avec les données d'une candidature.
class InterviewFormDialog extends StatefulWidget {
  final String? initialJobTitle;
  final String? initialCompanyName;
  final String? initialJobDescription;
  final String initialLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const InterviewFormDialog({
    super.key,
    this.initialJobTitle,
    this.initialCompanyName,
    this.initialJobDescription,
    this.initialLanguage = 'fr',
    this.onLanguageChanged,
  });

  @override
  State<InterviewFormDialog> createState() => _InterviewFormDialogState();
}

class _InterviewFormDialogState extends State<InterviewFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _jobTitleController;
  late final TextEditingController _companyController;
  late final TextEditingController _descriptionController;
  PlatformFile? _cvFile;
  late String _language;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _jobTitleController = TextEditingController(text: widget.initialJobTitle);
    _companyController = TextEditingController(text: widget.initialCompanyName);
    _descriptionController = TextEditingController(text: widget.initialJobDescription);
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text(t.t('interview.new_session')),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _jobTitleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.t('interview.job_title_label'),
                    hintText: t.t('interview.job_title_hint'),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return t.t('interview.job_title_required');
                    return validateJobTitleField(v.trim(), t);
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _companyController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.t('interview.company_label'),
                    hintText: t.t('interview.company_hint'),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? t.t('interview.company_required')
                      : null,
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: t.t('interview.job_desc_label'),
                    hintText: t.t('interview.job_desc_hint'),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? t.t('interview.job_desc_required')
                      : null,
                ),
                SizedBox(height: 12.h),
                // Upload CV
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() => _cvFile = result.files.first);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
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
                          size: 20.sp,
                          color: _cvFile != null ? cs.primary : cs.onSurfaceVariant,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _cvFile?.name ?? t.t('interview.cv_pick'),
                            style: TextStyle(fontSize: 12.sp, color: _cvFile != null ? cs.onSurface : cs.onSurfaceVariant),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_cvFile != null)
                          GestureDetector(
                            onTap: () => setState(() => _cvFile = null),
                            child: Icon(Icons.close_rounded, size: 16.sp, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  onTap: () => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    labelText: t.t('interview.language_label'),
                  ),
                  items: [
                    DropdownMenuItem(value: 'fr', child: Text(t.t('onboarding.language_fr'))),
                    DropdownMenuItem(value: 'en', child: Text(t.t('onboarding.language_en'))),
                  ],
                  onChanged: (v) {
                    setState(() => _language = v!);
                    widget.onLanguageChanged?.call(v!);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.t('settings.cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_cvFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.t('interview.cv_required'))),
              );
              return;
            }
            Navigator.pop(context, {
              'job_title': _jobTitleController.text.trim(),
              'company_name': _companyController.text.trim().isEmpty
                  ? null
                  : _companyController.text.trim(),
              'job_description': _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              'cv_path': _cvFile?.path,
              'language': _language,
            });
          },
          child: Text(t.t('interview.start_button')),
        ),
      ],
    );
  }
}
