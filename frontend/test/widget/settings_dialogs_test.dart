import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/set_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';

/// Traductions de test pour les dialogues settings.
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
  'settings.set_password_desc':
      'Définissez un mot de passe pour vous connecter par email.',
  'settings.change_email': "Modifier l'email",
  'settings.new_email': 'Nouvel email',
  'settings.password_confirm': 'Mot de passe',
  'settings.send_code': 'Envoyer le code',
  'settings.confirm': 'Vérifier',
  'settings.enter_email_code': 'Entrez le code reçu par email',
  'settings.email_code_sent': 'Code envoyé',
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

/// Wrapper qui affiche automatiquement le dialog via showDialog.
Widget _testApp(Widget dialog) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [_TestLocDelegate()],
      home: Builder(
        builder: (context) {
          // Affiche le dialog automatiquement après le build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(context: context, builder: (_) => dialog);
          });
          return const Scaffold();
        },
      ),
    ),
  );
}

/// Soumet le formulaire en appuyant sur le bouton Enregistrer.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
}

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // ChangePasswordDialog
  // ────────────────────────────────────────────────────────────────────────────
  group('ChangePasswordDialog', () {
    testWidgets('affiche les 3 champs mot de passe', (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe actuel'), findsOneWidget);
      expect(find.text('Nouveau mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    });

    testWidgets('affiche les boutons Enregistrer et Annuler', (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('affiche les icônes de visibilité', (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      // 2 icônes visibility_off (current + new), confirm n'en a pas
      expect(find.byIcon(Icons.visibility_off_rounded), findsNWidgets(2));
    });

    testWidgets('valide le mot de passe actuel vide', (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      await _tapSave(tester);

      expect(find.text('Champ requis'), findsWidgets);
    });

    testWidgets('valide le nouveau mot de passe trop court', (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      // Remplir le mot de passe actuel
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'OldPass1!');
      // Nouveau mot de passe trop court
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'Ab1!');
      // Confirmer identique
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'), 'Ab1!');

      await _tapSave(tester);

      expect(
          find.text('8 caractères minimum avec un caractère spécial'), findsOneWidget);
    });

    testWidgets('valide le nouveau mot de passe sans caractère spécial',
        (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'OldPass1!');
      // 8+ caractères mais sans caractère spécial
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'Abcdefgh1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
          'Abcdefgh1');

      await _tapSave(tester);

      expect(
          find.text('8 caractères minimum avec un caractère spécial'), findsOneWidget);
    });

    testWidgets('valide la non-correspondance des mots de passe',
        (tester) async {
      await tester.pumpWidget(_testApp(const ChangePasswordDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'OldPass1!');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'NewPass1!');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
          'Different1!');

      await _tapSave(tester);

      expect(
          find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SetPasswordDialog
  // ────────────────────────────────────────────────────────────────────────────
  group('SetPasswordDialog', () {
    testWidgets('affiche 2 champs (nouveau + confirmer) sans mot de passe actuel',
        (tester) async {
      await tester.pumpWidget(_testApp(const SetPasswordDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      // Pas de champ mot de passe actuel
      expect(find.text('Mot de passe actuel'), findsNothing);
    });

    testWidgets('affiche les boutons Enregistrer et Annuler', (tester) async {
      await tester.pumpWidget(_testApp(const SetPasswordDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('affiche le texte de description pour les comptes LinkedIn',
        (tester) async {
      await tester.pumpWidget(_testApp(const SetPasswordDialog()));
      await tester.pumpAndSettle();

      expect(
          find.text('Définissez un mot de passe pour vous connecter par email.'),
          findsOneWidget);
    });

    testWidgets('valide le nouveau mot de passe vide', (tester) async {
      await tester.pumpWidget(_testApp(const SetPasswordDialog()));
      await tester.pumpAndSettle();

      await _tapSave(tester);

      expect(find.text('Champ requis'), findsWidgets);
    });

    testWidgets('valide la non-correspondance des mots de passe',
        (tester) async {
      await tester.pumpWidget(_testApp(const SetPasswordDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
          'ValidPass1!');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
          'Different1!');

      await _tapSave(tester);

      expect(
          find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ChangeEmailDialog
  // ────────────────────────────────────────────────────────────────────────────
  group('ChangeEmailDialog', () {
    testWidgets('affiche les champs email et mot de passe initialement',
        (tester) async {
      await tester.pumpWidget(
          _testApp(const ChangeEmailDialog(currentEmail: 'user@test.com')));
      await tester.pumpAndSettle();

      expect(find.text('Nouvel email'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      // Affiche l'email actuel
      expect(find.text('user@test.com'), findsOneWidget);
    });

    testWidgets('affiche le bouton Envoyer le code', (tester) async {
      await tester.pumpWidget(
          _testApp(const ChangeEmailDialog(currentEmail: 'user@test.com')));
      await tester.pumpAndSettle();

      expect(find.text('Envoyer le code'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });
  });
}
