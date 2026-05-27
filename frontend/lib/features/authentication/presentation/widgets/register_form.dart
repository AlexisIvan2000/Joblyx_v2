import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/presentation/widgets/verify_email_dialog.dart';
import 'package:frontend/core/utils/haptic.dart';
import 'package:frontend/core/utils/password_validator.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  final _authService = AuthService();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }
    TextInput.finishAutofillContext();
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _authService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final verified = await showVerifyEmailDialog(
        context,
        _emailController.text.trim(),
      );
      if (!mounted) return;
      if (verified) {
        context.go('/dashboard');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      AppSnackbar.error(context, t.t(e.key));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20.sp),
      suffixIcon: suffixIcon,
      helperText: helperText,
      helperMaxLines: 2,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          children: [
            // First & Last name side by side
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'first_name_field',
                    child: TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: _inputDecoration(
                        label: t.t('register.first_name'),
                        icon: Icons.person_outline,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? t.t('register.no_first_name')
                          : null,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Semantics(
                    label: 'last_name_field',
                    child: TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: _inputDecoration(
                        label: t.t('register.last_name'),
                        icon: Icons.person_outline,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? t.t('register.no_last_name')
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Email
            Semantics(
              label: 'email_field',
              child: TextFormField(
                controller: _emailController,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: t.t('register.email'),
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.t('register.email_required');
                  }
                  if (!_emailRegex.hasMatch(value)) {
                    return t.t('register.email_invalid');
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 14.h),
            // Password
            Semantics(
              label: 'password_field',
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _inputDecoration(
                  label: t.t('register.password'),
                  icon: Icons.lock_outline,
                  helperText: t.t('register.password_hint'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20.sp,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.t('register.no_password');
                  }
                  if (!isStrongPassword(value)) {
                    return t.t('register.invalid_password');
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 24.h),
            // Register button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: FilledButton(
                onPressed: _isLoading ? null : () { Haptic.heavy(); _submit(); },
                style: FilledButton.styleFrom(
                  textStyle: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22.sp,
                        height: 22.sp,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: cs.onPrimary,
                        ),
                      )
                    : Text(t.t('register.register')),
              ),
            ),
            SizedBox(height: 20.h),
            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.t('register.have_account'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Text(
                    t.t('register.login'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
