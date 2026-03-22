import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/domain/user_failure.dart';

class EditProfileDialog extends StatefulWidget {
  final String firstName;
  final String lastName;

  const EditProfileDialog({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final _userService = UserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final t = AppLocalizations.of(context);

    try {
      await _userService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      final key = UserFailure.resolve(detail as String?, statusCode: e.response?.statusCode);
      AppSnackbar.error(context, t.t(key));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded, size: 40.sp, color: cs.primary),
              SizedBox(height: 12.h),
              Text(t.t('settings.edit_profile'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.t('settings.first_name'),
                  prefixIcon: Icon(Icons.person_outline, size: 20.sp),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.t('settings.required') : null,
              ),
              SizedBox(height: 14.h),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.t('settings.last_name'),
                  prefixIcon: Icon(Icons.person_outline, size: 20.sp),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? t.t('settings.required') : null,
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(minimumSize: Size(0, 46.h)),
                      child: Text(t.t('settings.cancel')),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: Size(0, 46.h)),
                      child: _isLoading
                          ? SizedBox(width: 20.sp, height: 20.sp,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                          : Text(t.t('settings.save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
