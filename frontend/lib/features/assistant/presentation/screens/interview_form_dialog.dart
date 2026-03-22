import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Dialog rapide pour démarrer un nouvel entretien.
/// Peut être pré-rempli avec les données d'une candidature.
class InterviewFormDialog extends StatefulWidget {
  final String? initialJobTitle;
  final String? initialCompanyName;
  final String? initialJobDescription;

  const InterviewFormDialog({
    super.key,
    this.initialJobTitle,
    this.initialCompanyName,
    this.initialJobDescription,
  });

  @override
  State<InterviewFormDialog> createState() => _InterviewFormDialogState();
}

class _InterviewFormDialogState extends State<InterviewFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _jobTitleController;
  late final TextEditingController _companyController;
  late final TextEditingController _descriptionController;
  String _language = 'fr';

  @override
  void initState() {
    super.initState();
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
                  decoration: InputDecoration(
                    labelText: t.t('interview.job_title_label'),
                    hintText: t.t('interview.job_title_hint'),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? t.t('interview.job_title_required')
                      : null,
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: t.t('interview.company_label'),
                    hintText: t.t('interview.company_hint'),
                  ),
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: t.t('interview.job_desc_label'),
                    hintText: t.t('interview.job_desc_hint'),
                  ),
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: t.t('interview.language_label'),
                  ),
                  items: [
                    DropdownMenuItem(value: 'fr', child: Text(t.t('onboarding.language_fr'))),
                    DropdownMenuItem(value: 'en', child: Text(t.t('onboarding.language_en'))),
                  ],
                  onChanged: (v) => setState(() => _language = v!),
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
            Navigator.pop(context, {
              'job_title': _jobTitleController.text.trim(),
              'company_name': _companyController.text.trim().isEmpty
                  ? null
                  : _companyController.text.trim(),
              'job_description': _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              'language': _language,
            });
          },
          child: Text(t.t('interview.start_button')),
        ),
      ],
    );
  }
}
