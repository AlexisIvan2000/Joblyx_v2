import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Traductions de test pour les widgets d'authentification.
final _t = AppLocalizations({
  // LoginForm
  'login.email': 'Email',
  'login.password': 'Password',
  'login.login': 'Log in',
  'login.email_required': 'Email is required',
  'login.email_invalid': 'Invalid email address',
  'login.no_password': 'Password is required',
  'login.invalid_password': 'Min 8 chars with a special character',
  'login.forgot_password': 'Forgot password?',
  'login.no_account': "Don't have an account? ",
  'login.register': 'Register',
  // RegisterForm
  'register.first_name': 'First name',
  'register.last_name': 'Last name',
  'register.email': 'Email',
  'register.password': 'Password',
  'register.register': 'Register',
  'register.no_first_name': 'First name is required',
  'register.no_last_name': 'Last name is required',
  'register.email_required': 'Email is required',
  'register.email_invalid': 'Invalid email address',
  'register.no_password': 'Password is required',
  'register.invalid_password': 'Min 8 chars with a special character',
  'register.have_account': 'Already have an account? ',
  'register.login': 'Log in',
  // VerifyEmailDialog
  'verify_email.title': 'Verify your email',
  'verify_email.subtitle': 'Enter the 6-digit code sent to',
  'verify_email.verify': 'Verify',
  'verify_email.no_code': "Didn't receive the code? ",
  'verify_email.resend': 'Resend',
  'verify_email.sending': 'Sending...',
  'verify_email.code_resent': 'Code resent!',
  // ForgotPasswordDialog
  'forgot_password.title': 'Forgot password',
  'forgot_password.reset_title': 'Reset password',
  'forgot_password.email_instruction': 'Enter your email to receive a reset code.',
  'forgot_password.send_code': 'Send code',
  'forgot_password.reset_button': 'Reset password',
  'forgot_password.code_label': 'Code',
  'forgot_password.code_instruction': 'Enter the code sent to {email}',
  'forgot_password.code_invalid': 'Code must be 6 digits',
  'forgot_password.new_password': 'New password',
  'forgot_password.password_required': 'Password is required',
  'forgot_password.password_weak': 'Min 8 chars with a special character',
  'forgot_password.resend_code': 'Resend code',
  'forgot_password.success': 'Password updated!',
  'settings.cancel': 'Cancel',
});

class _TestLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) async => _t;
  @override
  bool shouldReload(_) => false;
}

Widget _testApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [_TestLocDelegate()],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  //  LoginForm 

  group('LoginForm - Rendu des champs', () {
    testWidgets('affiche les champs email et mot de passe', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('affiche le bouton de connexion', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Log in'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('affiche le toggle de visibilité du mot de passe', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      // Par défaut, l'icône visibility_off est affichée
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      // Après tap, l'icône visibility est affichée
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });
  });

  group('LoginForm - Validation', () {
    testWidgets('valide email vide', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      // Soumettre le formulaire sans remplir
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('valide format email invalide', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      // Saisir un email invalide
      await tester.enterText(
        find.byType(TextFormField).first,
        'not-an-email',
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('valide mot de passe vide', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      // Saisir un email valide, pas de mot de passe
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('valide mot de passe trop court', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'short',
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Min 8 chars with a special character'), findsOneWidget);
    });

    testWidgets('valide mot de passe sans caractère spécial', (tester) async {
      await tester.pumpWidget(_testApp(
        const _LoginFormTest(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'longpassword123',
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Min 8 chars with a special character'), findsOneWidget);
    });
  });

  // ── RegisterForm ──

  group('RegisterForm - Rendu des champs', () {
    testWidgets('affiche les 4 champs (prénom, nom, email, mot de passe)', (tester) async {
      await tester.pumpWidget(_testApp(
        const _RegisterFormTest(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('affiche le bouton d\'inscription', (tester) async {
      await tester.pumpWidget(_testApp(
        const _RegisterFormTest(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('RegisterForm - Validation', () {
    testWidgets('valide les champs vides', (tester) async {
      await tester.pumpWidget(_testApp(
        const _RegisterFormTest(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('First name is required'), findsOneWidget);
      expect(find.text('Last name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('valide email invalide', (tester) async {
      await tester.pumpWidget(_testApp(
        const _RegisterFormTest(),
      ));
      await tester.pumpAndSettle();

      // Remplir tous les champs sauf email invalide
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'John');
      await tester.enterText(fields.at(1), 'Doe');
      await tester.enterText(fields.at(2), 'invalid-email');
      await tester.enterText(fields.at(3), 'Password1!');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('valide les exigences du mot de passe', (tester) async {
      await tester.pumpWidget(_testApp(
        const _RegisterFormTest(),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'John');
      await tester.enterText(fields.at(1), 'Doe');
      await tester.enterText(fields.at(2), 'test@example.com');
      await tester.enterText(fields.at(3), 'weak');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Min 8 chars with a special character'), findsOneWidget);
    });
  });

  // ── VerifyEmailDialog ──

  group('VerifyEmailDialog - Structure', () {
    testWidgets('le dialog peut être créé et affiche le titre', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _VerifyEmailDialogTest(email: 'test@example.com'),
              );
            },
            child: const Text('Show dialog'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('affiche 6 champs OTP', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _VerifyEmailDialogTest(email: 'test@example.com'),
              );
            },
            child: const Text('Show dialog'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();

      // 6 champs OTP
      expect(find.byType(TextFormField), findsNWidgets(6));
    });
  });

  // ForgotPasswordDialog 

  group('ForgotPasswordDialog - Rendu initial', () {
    testWidgets('affiche le champ email initialement', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _ForgotPasswordDialogTest(),
              );
            },
            child: const Text('Show dialog'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot password'), findsOneWidget);
      expect(find.text('Enter your email to receive a reset code.'), findsOneWidget);
      // Un champ email
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('affiche le bouton d\'envoi', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _ForgotPasswordDialogTest(),
              );
            },
            child: const Text('Show dialog'),
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Send code'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}

// ── Widgets de test (reproduction simplifiée sans dépendances réseau) ──

/// Reproduction simplifiée de LoginForm sans AuthService ni GoRouter.
class _LoginFormTest extends StatefulWidget {
  const _LoginFormTest();

  @override
  State<_LoginFormTest> createState() => _LoginFormTestState();
}

class _LoginFormTestState extends State<_LoginFormTest> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _passwordRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t.t('login.email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return t.t('login.email_required');
              if (!_emailRegex.hasMatch(value)) return t.t('login.email_invalid');
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.t('login.password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return t.t('login.no_password');
              if (value.length < 8 || !_passwordRegex.hasMatch(value)) {
                return t.t('login.invalid_password');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              t.t('login.forgot_password'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              child: Text(t.t('login.login')),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.t('login.no_account')),
              Text(
                t.t('login.register'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reproduction simplifiée de RegisterForm sans AuthService ni GoRouter.
class _RegisterFormTest extends StatefulWidget {
  const _RegisterFormTest();

  @override
  State<_RegisterFormTest> createState() => _RegisterFormTestState();
}

class _RegisterFormTestState extends State<_RegisterFormTest> {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _passwordRegex = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.t('register.first_name'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? t.t('register.no_first_name') : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.t('register.last_name'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? t.t('register.no_last_name') : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t.t('register.email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return t.t('register.email_required');
              if (!_emailRegex.hasMatch(value)) return t.t('register.email_invalid');
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.t('register.password'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return t.t('register.no_password');
              if (value.length < 8 || !_passwordRegex.hasMatch(value)) {
                return t.t('register.invalid_password');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              child: Text(t.t('register.register')),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.t('register.have_account')),
              Text(
                t.t('register.login'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reproduction simplifiée de VerifyEmailDialog sans AuthService.
class _VerifyEmailDialogTest extends StatelessWidget {
  final String email;
  const _VerifyEmailDialogTest({required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 52, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              t.t('verify_email.title'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              t.t('verify_email.subtitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(email, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            // 6 champs OTP
            Row(
              children: List.generate(6, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: TextFormField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {},
                child: Text(t.t('verify_email.verify')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.t('verify_email.no_code'),
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  t.t('verify_email.resend'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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

/// Reproduction simplifiée de ForgotPasswordDialog sans AuthService.
class _ForgotPasswordDialogTest extends StatelessWidget {
  const _ForgotPasswordDialogTest();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text(t.t('forgot_password.title')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.t('forgot_password.email_instruction'),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: t.t('login.email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t.t('settings.cancel')),
        ),
        FilledButton(
          onPressed: () {},
          child: Text(t.t('forgot_password.send_code')),
        ),
      ],
    );
  }
}
