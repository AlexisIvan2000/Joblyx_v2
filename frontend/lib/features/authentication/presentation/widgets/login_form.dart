import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/authentication/presentation/screens/register_screen.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _passwordRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
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
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20.sp),
      suffixIcon: suffixIcon,
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
            // Email
            Semantics(
              label: 'email_field',
              child: TextFormField(
                controller: _emailController,
                autofillHints: const [AutofillHints.username],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: t.t('login.email'),
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.t('login.email_required');
                  }
                  if (!_emailRegex.hasMatch(value)) {
                    return t.t('login.email_invalid');
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
                autofillHints: const [AutofillHints.password],
                decoration: _inputDecoration(
                  label: t.t('login.password'),
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
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
                    return t.t('login.no_password');
                  }
                  if (value.length < 8 || !_passwordRegex.hasMatch(value)) {
                    return t.t('login.invalid_password');
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 8.h),
            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: Text(
                  t.t('login.forgot_password'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Login button
            Semantics(
              label: 'login_button',
              child: SizedBox(
                width: double.infinity,
                height: 54.h,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(t.t('login.login')),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            // Register link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.t('login.no_account'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: Text(
                    t.t('login.register'),
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
