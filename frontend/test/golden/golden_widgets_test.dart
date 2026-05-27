// Golden tests — capture les widgets sur 3 tailles d'écran.
// Première exécution : flutter test --update-goldens test/golden/
// Exécutions suivantes : flutter test test/golden/ (compare les screenshots)

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/set_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/edit_profile_dialog.dart';

//  Traductions 

final _t = AppLocalizations({
  'settings.current_password': 'Mot de passe actuel',
  'settings.new_password': 'Nouveau mot de passe',
  'settings.confirm_password': 'Confirmer le mot de passe',
  'settings.save': 'Enregistrer',
  'settings.cancel': 'Annuler',
  'settings.required': 'Champ requis',
  'settings.password_rules': '8 caractères min. avec un caractère spécial',
  'settings.passwords_mismatch': 'Les mots de passe ne correspondent pas',
  'settings.change_password': 'Modifier le mot de passe',
  'settings.set_password': 'Définir un mot de passe',
  'settings.set_password_desc': 'Définissez un mot de passe pour vous connecter par email.',
  'settings.change_email': 'Modifier l\'email',
  'settings.new_email': 'Nouvel email',
  'settings.password_confirm': 'Votre mot de passe',
  'settings.send_code': 'Envoyer le code',
  'profile_screen.edit_name': 'Modifier le nom',
  'profile_screen.first_name': 'Prénom',
  'profile_screen.last_name': 'Nom',
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

//  Tailles d'écran 

const _sizes = {
  'small': Size(320, 568),
  'phone': Size(375, 812),
  'tablet': Size(768, 1024),
};

//  Helper 

/// Configure la taille du viewport et pump un dialog dans une MaterialApp.
Future<void> _pumpDialog(WidgetTester tester, Size size, Widget dialog) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: size,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [_TestLocDelegate()],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          useMaterial3: true,
        ),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(context: context, builder: (_) => dialog);
            });
            return const Scaffold();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Configure la taille et pump un widget inline.
Future<void> _pumpWidget(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: size,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [_TestLocDelegate()],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          useMaterial3: true,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Golden Tests 

void main() {
  // ChangePasswordDialog
  group('Golden — ChangePasswordDialog', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpDialog(tester, entry.value, const ChangePasswordDialog());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/change_password_${entry.key}.png'),
        );
      });
    }
  });

  // SetPasswordDialog
  group('Golden — SetPasswordDialog', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpDialog(tester, entry.value, const SetPasswordDialog());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/set_password_${entry.key}.png'),
        );
      });
    }
  });

  // ChangeEmailDialog
  group('Golden — ChangeEmailDialog', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpDialog(tester, entry.value, const ChangeEmailDialog(currentEmail: 'user@joblyx.com'));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/change_email_${entry.key}.png'),
        );
      });
    }
  });

  // EditProfileDialog
  group('Golden — EditProfileDialog', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpDialog(tester, entry.value, const EditProfileDialog(firstName: 'Alexis', lastName: 'Kombou'));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/edit_profile_${entry.key}.png'),
        );
      });
    }
  });

  // OTP 6 champs
  group('Golden — OTP 6 champs', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpWidget(tester, entry.value, _OtpFields());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/otp_fields_${entry.key}.png'),
        );
      });
    }
  });

  // LoginForm
  group('Golden — LoginForm', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpWidget(tester, entry.value, _LoginForm());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/login_form_${entry.key}.png'),
        );
      });
    }
  });

  // RegisterForm
  group('Golden — RegisterForm', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpWidget(tester, entry.value, _RegisterForm());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/register_form_${entry.key}.png'),
        );
      });
    }
  });

  // ForgotPasswordDialog
  group('Golden — ForgotPasswordDialog', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpDialog(tester, entry.value, _ForgotPasswordDialog());
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/forgot_password_${entry.key}.png'),
        );
      });
    }
  });
}

//  Widgets reproductions 

class _OtpFields extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text('Vérification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Code envoyé à user@joblyx.com', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) => SizedBox(
              width: 42,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () {}, child: const Text('Vérifier')),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () {}, child: const Text('Renvoyer le code')),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Connexion', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 14),
          TextFormField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.visibility_off_rounded), onPressed: () {}),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () {}, child: const Text('Mot de passe oublié ?')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: () {}, child: const Text('Se connecter')),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Inscription', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextFormField(decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextFormField(decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 14),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline_rounded)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: () {}, child: const Text('S\'inscrire')),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.lock_reset_rounded, size: 40, color: cs.primary),
      title: const Text('Mot de passe oublié'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Entrez votre email pour recevoir un code.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Annuler')),
        FilledButton(onPressed: () {}, child: const Text('Envoyer le code')),
      ],
    );
  }
}
