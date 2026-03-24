import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';

/// Affiche le dialog forgot password et retourne true si le mot de passe a été réinitialisé.
Future<bool> showForgotPasswordDialog(BuildContext context, {String? initialEmail}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
  return result ?? false;
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  const _ForgotPasswordDialog({this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _passwordRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) return;

    setState(() => _isLoading = true);
    try {
      await _authService.forgotPassword(email: email);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } catch (_) {
      // On ne révèle pas si l'email existe ou non — afficher quand même l'étape 2
      if (mounted) setState(() => _codeSent = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final t = AppLocalizations.of(context);

    try {
      await _authService.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      AppSnackbar.success(context, t.t('forgot_password.success'));
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, t.t(e.key));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text(_codeSent ? t.t('forgot_password.reset_title') : t.t('forgot_password.title')),
      content: SizedBox(
        width: double.maxFinite,
        child: _codeSent ? _buildResetForm(t, cs) : _buildEmailForm(t, cs),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t.t('settings.cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : (_codeSent ? _resetPassword : _sendCode),
          child: _isLoading
              ? SizedBox(
                  width: 18.sp, height: 18.sp,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
              : Text(_codeSent ? t.t('forgot_password.reset_button') : t.t('forgot_password.send_code')),
        ),
      ],
    );
  }

  Widget _buildEmailForm(AppLocalizations t, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.t('forgot_password.email_instruction'),
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        SizedBox(height: 14.h),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: t.t('login.email'),
            prefixIcon: Icon(Icons.email_outlined, size: 20.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm(AppLocalizations t, ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.t('forgot_password.code_instruction').replaceAll('{email}', _emailController.text.trim()),
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 14.h),
          // Code OTP
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: t.t('forgot_password.code_label'),
              prefixIcon: Icon(Icons.pin_outlined, size: 20.sp),
              counterText: '',
            ),
            validator: (v) => v == null || v.trim().length != 6
                ? t.t('forgot_password.code_invalid')
                : null,
          ),
          SizedBox(height: 12.h),
          // Nouveau mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.t('forgot_password.new_password'),
              prefixIcon: Icon(Icons.lock_outline, size: 20.sp),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 20.sp,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return t.t('forgot_password.password_required');
              if (v.length < 8 || !_passwordRegex.hasMatch(v)) return t.t('forgot_password.password_weak');
              return null;
            },
          ),
          SizedBox(height: 8.h),
          // Renvoyer le code
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _isLoading ? null : _sendCode,
              child: Text(t.t('forgot_password.resend_code'),
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
