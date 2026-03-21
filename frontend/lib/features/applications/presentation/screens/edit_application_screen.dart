import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/applications/presentation/widgets/status_selector.dart';

class EditApplicationScreen extends ConsumerStatefulWidget {
  final String applicationId;
  const EditApplicationScreen({super.key, required this.applicationId});

  @override
  ConsumerState<EditApplicationScreen> createState() => _EditApplicationScreenState();
}

class _EditApplicationScreenState extends ConsumerState<EditApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _jobUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'saved';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(applicationServiceProvider).getById(widget.applicationId);
      if (!mounted) return;
      setState(() {
        _companyController.text = data['company_name'] as String? ?? '';
        _jobTitleController.text = data['job_title'] as String? ?? '';
        _jobUrlController.text = data['job_url'] as String? ?? '';
        _descriptionController.text = data['job_description'] as String? ?? '';
        _notesController.text = data['notes'] as String? ?? '';
        _status = data['status'] as String? ?? 'saved';
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _jobTitleController.dispose();
    _jobUrlController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final t = AppLocalizations.of(context);

    try {
      final data = <String, dynamic>{
        'company_name': _companyController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'status': _status,
        'job_url': _jobUrlController.text.trim().isEmpty ? null : _jobUrlController.text.trim(),
        'job_description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await ref.read(applicationsProvider.notifier).updateApplication(widget.applicationId, data);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t('application_detail.update_error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('application_detail.edit_title')),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(width: 20.sp, height: 20.sp,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary))
                : Text(t.t('application_detail.save_button'),
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
                children: [
                  // Job title
                  _label(t.t('applications_screen.job_title_label'), cs),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _jobTitleController,
                    textInputAction: TextInputAction.next,
                    decoration: _deco(t.t('applications_screen.job_title_hint'), cs),
                    validator: (v) => (v == null || v.trim().isEmpty) ? t.t('applications_screen.field_required') : null,
                  ),
                  SizedBox(height: 16.h),

                  // Company
                  _label(t.t('applications_screen.company_name'), cs),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _companyController,
                    textInputAction: TextInputAction.next,
                    decoration: _deco(t.t('applications_screen.company_hint'), cs),
                    validator: (v) => (v == null || v.trim().isEmpty) ? t.t('applications_screen.field_required') : null,
                  ),
                  SizedBox(height: 16.h),

                  // Status
                  _label(t.t('applications_screen.status_label'), cs),
                  SizedBox(height: 8.h),
                  StatusSelector(current: _status, onChanged: (s) => setState(() => _status = s)),
                  SizedBox(height: 16.h),

                  // Job URL
                  _label(t.t('applications_screen.job_url_label'), cs),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _jobUrlController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    decoration: _deco(t.t('applications_screen.job_url_hint'), cs),
                  ),
                  SizedBox(height: 16.h),

                  // Description
                  _label(t.t('applications_screen.description_label'), cs),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _deco(t.t('applications_screen.description_hint'), cs),
                  ),
                  SizedBox(height: 16.h),

                  // Notes
                  _label(t.t('applications_screen.notes_label'), cs),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _deco(t.t('applications_screen.notes_hint'), cs),
                  ),
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
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.error)),
    );
  }
}
