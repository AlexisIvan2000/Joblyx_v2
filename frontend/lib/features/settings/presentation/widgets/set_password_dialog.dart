import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/domain/user_failure.dart';

class SetPasswordDialog extends StatefulWidget {
  const SetPasswordDialog({super.key});

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _userService = UserService();
  bool _isLoading = false;
  bool _showNew = false;

  static final _specialCharRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final t = AppLocalizations.of(context);

    try {
      await _userService.setPassword(newPassword: _newController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final detail = data is Map ? (data['message'] ?? data['detail']) : null;
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
              Icon(Icons.lock_outline_rounded, size: 40.sp, color: cs.primary),
              SizedBox(height: 12.h),
              Text(t.t('settings.set_password'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Text(t.t('settings.set_password_desc'),
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _newController,
                obscureText: !_showNew,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.t('settings.new_password'),
                  prefixIcon: Icon(Icons.lock_open_rounded, size: 20.sp),
                  suffixIcon: IconButton(
                    icon: Icon(_showNew ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20.sp),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return t.t('settings.required');
                  if (v.length < 8 || !_specialCharRegex.hasMatch(v)) {
                    return t.t('settings.password_rules');
                  }
                  return null;
                },
              ),
              SizedBox(height: 14.h),
              TextFormField(
                controller: _confirmController,
                obscureText: !_showNew,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: t.t('settings.confirm_password'),
                  prefixIcon: Icon(Icons.lock_open_rounded, size: 20.sp),
                ),
                validator: (v) {
                  if (v != _newController.text) return t.t('settings.passwords_mismatch');
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
