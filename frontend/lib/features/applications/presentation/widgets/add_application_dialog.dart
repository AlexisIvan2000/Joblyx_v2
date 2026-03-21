import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/applications/presentation/widgets/cv_picker.dart';
import 'package:frontend/features/applications/presentation/widgets/status_selector.dart';

/// Résultat retourné par le dialog : données du formulaire + fichier CV optionnel.
class AddApplicationResult {
  final Map<String, dynamic> data;
  final PlatformFile? cvFile;
  const AddApplicationResult({required this.data, this.cvFile});

  String? get cvPath => cvFile?.path;
  String? get cvFilename => cvFile?.name;
}

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
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'saved';
  bool _showOptional = false;
  PlatformFile? _cvFile;
  DateTime _appliedAt = DateTime.now();

  @override
  void dispose() {
    _companyController.dispose();
    _jobTitleController.dispose();
    _jobUrlController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickCv(AppLocalizations t) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('applications_screen.cv_too_large'))),
        );
      }
      return;
    }
    setState(() => _cvFile = file);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'company_name': _companyController.text.trim(),
      'job_title': _jobTitleController.text.trim(),
      'status': _status,
      'applied_at': _appliedAt.toIso8601String(),
    };

    final url = _jobUrlController.text.trim();
    if (url.isNotEmpty) data['job_url'] = url;
    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) data['job_description'] = description;
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) data['notes'] = notes;

    Navigator.pop(context, AddApplicationResult(data: data, cvFile: _cvFile));
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
              // En-tête
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.t('applications_screen.add_title'),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 22.sp),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
              SizedBox(height: 20.h),

              // Entreprise
              _label(t.t('applications_screen.company_name'), cs),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _companyController, textInputAction: TextInputAction.next,
                decoration: _deco(t.t('applications_screen.company_hint'), cs),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.t('applications_screen.field_required') : null,
              ),
              SizedBox(height: 14.h),

              // Poste
              _label(t.t('applications_screen.job_title_label'), cs),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _jobTitleController, textInputAction: TextInputAction.next,
                decoration: _deco(t.t('applications_screen.job_title_hint'), cs),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.t('applications_screen.field_required') : null,
              ),
              SizedBox(height: 14.h),

              // Statut
              _label(t.t('applications_screen.status_label'), cs),
              SizedBox(height: 6.h),
              StatusSelector(current: _status, onChanged: (s) => setState(() => _status = s)),
              SizedBox(height: 14.h),

              // Date
              _label(t.t('applications_screen.date_label'), cs),
              SizedBox(height: 6.h),
              _buildDatePicker(cs),
              SizedBox(height: 14.h),

              // CV
              _label(t.t('applications_screen.cv_label'), cs),
              SizedBox(height: 6.h),
              CvPicker(file: _cvFile, onPick: () => _pickCv(t), onRemove: () => setState(() => _cvFile = null)),
              SizedBox(height: 14.h),

              // Champs optionnels (toggle)
              GestureDetector(
                onTap: () => setState(() => _showOptional = !_showOptional),
                child: Row(children: [
                  Icon(_showOptional ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20.sp, color: cs.primary),
                  SizedBox(width: 4.w),
                  Text(t.t('applications_screen.optional_fields'),
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.primary)),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
                child: _showOptional ? _buildOptionalFields(t, cs) : const SizedBox.shrink(),
              ),
              SizedBox(height: 24.h),

              // Bouton ajouter
              SizedBox(width: double.infinity, height: 48.h, child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
                child: Text(t.t('applications_screen.add_button'),
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(ColorScheme cs) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, initialDate: _appliedAt, firstDate: DateTime(2020), lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _appliedAt = picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 18.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Text(
            '${_appliedAt.day.toString().padLeft(2, '0')}/${_appliedAt.month.toString().padLeft(2, '0')}/${_appliedAt.year}',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ]),
      ),
    );
  }

  Widget _buildOptionalFields(AppLocalizations t, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 14.h),
      _label(t.t('applications_screen.job_url_label'), cs),
      SizedBox(height: 6.h),
      TextFormField(
        controller: _jobUrlController, textInputAction: TextInputAction.next,
        keyboardType: TextInputType.url, decoration: _deco(t.t('applications_screen.job_url_hint'), cs),
      ),
      SizedBox(height: 14.h),
      _label(t.t('applications_screen.description_label'), cs),
      SizedBox(height: 6.h),
      TextFormField(
        controller: _descriptionController, textInputAction: TextInputAction.next,
        maxLines: 4, decoration: _deco(t.t('applications_screen.description_hint'), cs),
      ),
      SizedBox(height: 14.h),
      _label(t.t('applications_screen.notes_label'), cs),
      SizedBox(height: 6.h),
      TextFormField(
        controller: _notesController, textInputAction: TextInputAction.done,
        maxLines: 3, decoration: _deco(t.t('applications_screen.notes_hint'), cs),
      ),
    ]);
  }

  Widget _label(String text, ColorScheme cs) {
    return Text(text, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface));
  }

  InputDecoration _deco(String hint, ColorScheme cs) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: cs.error)),
    );
  }
}
