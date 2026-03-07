import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/domain/user_failure.dart';

class ChangeEmailDialog extends StatefulWidget {
  final String currentEmail;
  const ChangeEmailDialog({super.key, required this.currentEmail});

  @override
  State<ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<ChangeEmailDialog> {
  final _userService = UserService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;

  // OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;

  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _requestChange() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) return;
    if (!_emailRegex.hasMatch(_emailController.text.trim())) return;

    setState(() => _isLoading = true);
    final t = AppLocalizations.of(context);

    try {
      await _userService.changeEmail(
        newEmail: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppSnackbar.success(context, t.t('settings.email_code_sent'));
      _otpFocusNodes[0].requestFocus();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      final key = UserFailure.resolve(detail as String?, statusCode: e.response?.statusCode);
      AppSnackbar.error(context, t.t(key));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmChange() async {
    if (_otpCode.length != 6) return;

    setState(() => _isVerifying = true);
    final t = AppLocalizations.of(context);

    try {
      await _userService.confirmEmailChange(code: _otpCode);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      final key = UserFailure.resolve(detail as String?, statusCode: e.response?.statusCode);
      AppSnackbar.error(context, t.t(key));
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.email_outlined, size: 40.sp, color: cs.primary),
            SizedBox(height: 12.h),
            Text(t.t('settings.change_email'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 6.h),
            Text(widget.currentEmail,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            SizedBox(height: 20.h),
            if (!_codeSent) ...[
              // Étape 1 : Nouveau email + mot de passe
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: t.t('settings.new_email'),
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20.sp),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
              SizedBox(height: 14.h),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.t('settings.password_confirm'),
                  prefixIcon: Icon(Icons.lock_rounded, size: 20.sp),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
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
                      onPressed: _isLoading ? null : _requestChange,
                      style: FilledButton.styleFrom(minimumSize: Size(0, 46.h)),
                      child: _isLoading
                          ? SizedBox(width: 20.sp, height: 20.sp,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                          : Text(t.t('settings.send_code')),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Étape 2 : Code OTP
              Text(t.t('settings.enter_email_code'),
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              SizedBox(height: 16.h),
              Row(
                children: List.generate(6, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      child: TextFormField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: cs.primary, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
                          if (value.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
                          if (_otpCode.length == 6) _confirmChange();
                        },
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _confirmChange,
                  child: _isVerifying
                      ? SizedBox(width: 20.sp, height: 20.sp,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                      : Text(t.t('settings.confirm')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
