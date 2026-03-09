import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

class AddApplicationDialog extends StatefulWidget {
  const AddApplicationDialog({super.key});

  @override
  State<AddApplicationDialog> createState() => _AddApplicationDialogState();
}

class _AddApplicationDialogState extends State<AddApplicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _jobUrlController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'applied';
  bool _showOptional = false;

  @override
  void dispose() {
    _companyController.dispose();
    _jobTitleController.dispose();
    _jobUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.t('applications_screen.add_title'),
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 22.sp),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Company name
              _buildLabel(t.t('applications_screen.company_name'), cs),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _companyController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  t.t('applications_screen.company_hint'), cs),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t.t('applications_screen.field_required')
                    : null,
              ),
              SizedBox(height: 14.h),

              // Job title
              _buildLabel(t.t('applications_screen.job_title_label'), cs),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _jobTitleController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  t.t('applications_screen.job_title_hint'), cs),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t.t('applications_screen.field_required')
                    : null,
              ),
              SizedBox(height: 14.h),

              // Status
              _buildLabel(t.t('applications_screen.status_label'), cs),
              SizedBox(height: 6.h),
              _StatusSelector(
                current: _status,
                cs: cs,
                t: t,
                onChanged: (s) => setState(() => _status = s),
              ),
              SizedBox(height: 14.h),

              // Toggle optional fields
              GestureDetector(
                onTap: () => setState(() => _showOptional = !_showOptional),
                child: Row(
                  children: [
                    Icon(
                      _showOptional
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20.sp,
                      color: cs.primary,
                    ),
                    SizedBox(width: 4.w),
                    Text(t.t('applications_screen.optional_fields'),
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                  ],
                ),
              ),

              // Optional fields
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _showOptional
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 14.h),
                          // Job URL
                          _buildLabel(
                              t.t('applications_screen.job_url_label'), cs),
                          SizedBox(height: 6.h),
                          TextFormField(
                            controller: _jobUrlController,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.url,
                            decoration: _inputDecoration(
                              t.t('applications_screen.job_url_hint'), cs),
                          ),
                          SizedBox(height: 14.h),
                          // Notes
                          _buildLabel(
                              t.t('applications_screen.notes_label'), cs),
                          SizedBox(height: 6.h),
                          TextFormField(
                            controller: _notesController,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            decoration: _inputDecoration(
                              t.t('applications_screen.notes_hint'), cs),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(height: 24.h),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(t.t('applications_screen.add_button'),
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ColorScheme cs) {
    return Text(text,
        style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: cs.onSurface));
  }

  InputDecoration _inputDecoration(String hint, ColorScheme cs) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: cs.error),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'company_name': _companyController.text.trim(),
      'job_title': _jobTitleController.text.trim(),
      'status': _status,
    };

    final url = _jobUrlController.text.trim();
    if (url.isNotEmpty) data['job_url'] = url;

    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) data['notes'] = notes;

    Navigator.pop(context, data);
  }
}

class _StatusSelector extends StatelessWidget {
  final String current;
  final ColorScheme cs;
  final AppLocalizations t;
  final ValueChanged<String> onChanged;

  const _StatusSelector({
    required this.current,
    required this.cs,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      ('applied', t.t('applications_screen.status_applied')),
      ('phone_screen', t.t('applications_screen.status_phone_screen')),
      ('technical', t.t('applications_screen.status_technical')),
      ('final_interview', t.t('applications_screen.status_final_interview')),
      ('offer', t.t('applications_screen.status_offer')),
    ];

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: statuses.map((s) {
        final isSelected = s.$1 == current;
        return GestureDetector(
          onTap: () => onChanged(s.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(s.$2,
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant)),
          ),
        );
      }).toList(),
    );
  }
}
