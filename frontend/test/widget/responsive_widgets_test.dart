// Tests visuels multi-tailles — vérifie que les dialogs, formulaires et
// composants critiques s'affichent sans overflow sur petits écrans,
// phones et tablettes.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/set_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/edit_profile_dialog.dart';

// ─── Traductions de test ──────────────────────────────────────

final _t = AppLocalizations({
  'settings.current_password': 'Mot de passe actuel',
  'settings.new_password': 'Nouveau mot de passe',
  'settings.confirm_password': 'Confirmer le mot de passe',
  'settings.save': 'Enregistrer',
  'settings.cancel': 'Annuler',
  'settings.required': 'Champ requis',
  'settings.password_rules': '8 caractères minimum avec un caractère spécial',
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
  'auth.verify_title': 'Vérification email',
  'auth.verify_subtitle': 'Code envoyé à',
  'auth.verify': 'Vérifier',
  'auth.resend_code': 'Renvoyer le code',
  'auth.forgot_title': 'Mot de passe oublié',
  'auth.forgot_subtitle': 'Entrez votre email',
  'auth.send_code': 'Envoyer le code',
  'auth.reset_title': 'Réinitialiser',
  'auth.new_password': 'Nouveau mot de passe',
  'auth.code_label': 'Code à 6 chiffres',
  'auth.reset_button': 'Réinitialiser',
  'applications_screen.add_title': 'Nouvelle candidature',
  'applications_screen.company_name': 'Entreprise',
  'applications_screen.job_title': 'Poste',
  'applications_screen.status_saved': 'Sauvegardée',
  'applications_screen.status_applied': 'Postulée',
  'applications_screen.more_options': 'Plus d\'options',
  'applications_screen.job_url': 'URL de l\'offre',
  'applications_screen.job_description': 'Description',
  'applications_screen.notes': 'Notes',
  'applications_screen.save': 'Enregistrer',
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

// ─── Tailles d'écran ──────────────────────────────────────────

const _screenSizes = {
  'petit_ecran_320x568': Size(320, 568),
  'phone_375x812': Size(375, 812),
  'tablette_768x1024': Size(768, 1024),
};

// ─── Helpers ──────────────────────────────────────────────────

/// Crée une app de test à une taille donnée avec un dialog auto-affiché.
Widget _testAppWithDialog(Size size, Widget dialog) {
  return ScreenUtilInit(
    designSize: size,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [_TestLocDelegate()],
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(context: context, builder: (_) => dialog);
          });
          return const Scaffold();
        },
      ),
    ),
  );
}

/// Crée une app de test à une taille donnée avec un widget inline.
Widget _testAppInline(Size size, Widget child) {
  return ScreenUtilInit(
    designSize: size,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [_TestLocDelegate()],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// Vérifie qu'il n'y a aucun overflow RenderFlex.
void _expectNoOverflow(WidgetTester tester) {
  final errors = tester.takeException();
  expect(errors, isNull, reason: 'Pas d\'erreur de rendu (overflow)');
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  // ChangePasswordDialog
  group('ChangePasswordDialog — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        tester.view.devicePixelRatio = tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_testAppWithDialog(entry.value, const ChangePasswordDialog()));
        await tester.pumpAndSettle();

        // Vérifier que le dialog est affiché
        expect(find.byType(Dialog), findsOneWidget);

        // Vérifier les 3 champs
        expect(find.byType(TextFormField), findsNWidgets(3));

        // Vérifier les boutons
        expect(find.byType(OutlinedButton), findsOneWidget); // Annuler
        expect(find.byType(FilledButton), findsOneWidget); // Enregistrer

        _expectNoOverflow(tester);
      });
    }
  });

  // SetPasswordDialog
  group('SetPasswordDialog — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_testAppWithDialog(entry.value, const SetPasswordDialog()));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        // 2 champs (nouveau + confirmer)
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.byType(FilledButton), findsOneWidget);

        _expectNoOverflow(tester);
      });
    }
  });

  // ChangeEmailDialog
  group('ChangeEmailDialog — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _testAppWithDialog(entry.value, const ChangeEmailDialog(currentEmail: 'test@example.com')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        // Étape 1 : email + password
        expect(find.byType(TextFormField), findsNWidgets(2));

        _expectNoOverflow(tester);
      });
    }
  });

  // EditProfileDialog
  group('EditProfileDialog — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _testAppWithDialog(entry.value, const EditProfileDialog(firstName: 'John', lastName: 'Doe')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        // 2 champs (prénom + nom)
        expect(find.byType(TextFormField), findsNWidgets(2));
        // Valeurs pré-remplies
        expect(find.text('John'), findsOneWidget);
        expect(find.text('Doe'), findsOneWidget);

        _expectNoOverflow(tester);
      });
    }
  });

  // Reproduction OTP 6 champs (pattern commun à verify_email et change_email)
  group('OTP 6 champs — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('6 champs OTP s\'affichent sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        // Reproduire le layout OTP tel qu'utilisé dans les dialogs
        await tester.pumpWidget(
          _testAppInline(entry.value, _OtpFieldsTest()),
        );
        await tester.pumpAndSettle();

        // 6 champs de saisie
        expect(find.byType(TextField), findsNWidgets(6));

        _expectNoOverflow(tester);
      });
    }
  });

  // LoginForm reproduction — champs email + password
  group('LoginForm layout — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('formulaire login s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _testAppInline(entry.value, _LoginFormTest()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.byType(FilledButton), findsOneWidget);

        _expectNoOverflow(tester);
      });
    }
  });

  // RegisterForm reproduction — 4 champs
  group('RegisterForm layout — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('formulaire register s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _testAppInline(entry.value, _RegisterFormTest()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.byType(FilledButton), findsOneWidget);

        _expectNoOverflow(tester);
      });
    }
  });

  // ForgotPasswordDialog reproduction — étape email
  group('ForgotPasswordDialog layout — responsive', () {
    for (final entry in _screenSizes.entries) {
      testWidgets('s\'affiche sans overflow sur ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _testAppWithDialog(entry.value, _ForgotPasswordTest()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget); // email

        _expectNoOverflow(tester);
      });
    }
  });
}

// ─── Widgets de test (reproductions légères) ──────────────────

/// Reproduction des 6 champs OTP côte à côte.
class _OtpFieldsTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Entrez le code à 6 chiffres'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) => SizedBox(
              width: 42,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

/// Reproduction du formulaire login.
class _LoginFormTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () {}, child: const Text('Se connecter')),
          ),
        ],
      ),
    );
  }
}

/// Reproduction du formulaire register.
class _RegisterFormTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            child: FilledButton(onPressed: () {}, child: const Text('S\'inscrire')),
          ),
        ],
      ),
    );
  }
}

/// Reproduction du dialog forgot password (étape 1 : email).
class _ForgotPasswordTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mot de passe oublié'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Entrez votre email pour recevoir un code de réinitialisation.'),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Annuler')),
        FilledButton(onPressed: () {}, child: const Text('Envoyer')),
      ],
    );
  }
}
