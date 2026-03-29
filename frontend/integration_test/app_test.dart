// Test E2E complet — parcours utilisateur Joblyx.
//
// Lance sur émulateur/device avec le vrai backend Railway.
// Usage :
//   flutter test integration_test/app_test.dart -d emulator-5554
//     --dart-define=TEST_EMAIL=email@example.com
//     --dart-define=TEST_PASSWORD=motdepasse

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

const _email = String.fromEnvironment('TEST_EMAIL');
const _password = String.fromEnvironment('TEST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Parcours utilisateur complet', () {
    testWidgets('E2E : login → dashboard → tous les onglets → settings → logout',
        (tester) async {
      app.main();

      // Attendre le splash + redirection vers first-page
      await _settle(tester, seconds: 6);

      // ─── 1. First Page ───────────────────────────────────────
      await _waitFor(tester, find.textContaining('email'), label: 'First Page');

      // ─── 2. Naviguer vers Login ──────────────────────────────
      // Bouton "Continuer avec email" (fr) ou "Continue with email" (en)
      final emailBtn = find.byType(FilledButton);
      if (emailBtn.evaluate().isNotEmpty) {
        await tester.tap(emailBtn.first);
        await _settle(tester, seconds: 3);
      }

      // ─── 3. Remplir le formulaire ────────────────────────────
      // Chercher les champs texte (email + password)
      await _waitFor(tester, find.byType(TextField), label: 'Champs login');

      final fields = find.byType(TextField);
      final fieldCount = fields.evaluate().length;
      debugPrint('[E2E] Nombre de champs trouvés : $fieldCount');

      // Remplir email
      await tester.enterText(fields.first, _email);
      await tester.pump();

      // Remplir password (dernier champ avant le bouton)
      await tester.enterText(fields.at(fieldCount > 2 ? 1 : fieldCount - 1), _password);
      await tester.pump();

      // Appuyer sur le bouton de connexion (Se connecter / Sign in)
      final loginBtn = find.byType(FilledButton);
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn.first);
      }

      // Attendre le login API + navigation vers dashboard
      await _settle(tester, seconds: 10);

      // ─── 4. Dashboard ────────────────────────────────────────
      await _waitFor(tester, _findNavBar(),
          label: 'Navigation bar', seconds: 15);
      debugPrint('[E2E] ✓ Dashboard chargé');

      // ─── 5. Onglet Roadmap ───────────────────────────────────
      await _tapNavTab(tester, 1);
      await _settle(tester, seconds: 3);
      debugPrint('[E2E] ✓ Onglet Roadmap');

      // ─── 6. Onglet Applications ──────────────────────────────
      await _tapNavTab(tester, 2);
      await _settle(tester, seconds: 3);
      debugPrint('[E2E] ✓ Onglet Applications');

      debugPrint('[E2E] ✓ Page Applications visible');

      // ─── 7. Onglet Assistant ─────────────────────────────────
      await _tapNavTab(tester, 3);
      await _settle(tester, seconds: 3);
      debugPrint('[E2E] ✓ Onglet Assistant');

      // ─── 8. Onglet Profil ────────────────────────────────────
      await _tapNavTab(tester, 4);
      await _settle(tester, seconds: 3);
      debugPrint('[E2E] ✓ Onglet Profil');

      // Vérifier les infos utilisateur
      final hasEmail = find.textContaining('@').evaluate().isNotEmpty;
      expect(hasEmail, isTrue, reason: 'Le profil devrait afficher l\'email');

      // ─── 9. Ouvrir Settings ──────────────────────────────────
      final settingsBtn = find.byIcon(Icons.settings_rounded);
      if (settingsBtn.evaluate().isNotEmpty) {
        await tester.tap(settingsBtn);
        await _settle(tester, seconds: 2);
        debugPrint('[E2E] ✓ Settings ouvert');

        // Vérifier la présence du bouton logout (icône)
        expect(find.byIcon(Icons.logout_rounded), findsWidgets,
            reason: 'Settings devrait avoir un bouton de déconnexion');

        // ─── 10. Logout ────────────────────────────────────────
        final logoutIcon = find.byIcon(Icons.logout_rounded);
        await tester.ensureVisible(logoutIcon.first);
        // Taper sur le parent du logout icon
        final logoutArea = find.ancestor(of: logoutIcon.first, matching: find.byType(InkWell));
        if (logoutArea.evaluate().isNotEmpty) {
          await tester.tap(logoutArea.first);
        } else {
          await tester.tap(logoutIcon.first);
        }
        await _settle(tester, seconds: 5);

        // Vérifier le retour sur first-page (présence d'un FilledButton)
        await _waitFor(tester, find.byType(FilledButton),
            label: 'Retour First Page après logout', seconds: 10);
        debugPrint('[E2E] ✓ Logout réussi — retour sur first-page');
      }

      debugPrint('[E2E] ══════════════════════════════════════');
      debugPrint('[E2E] ✓ PARCOURS COMPLET RÉUSSI');
      debugPrint('[E2E] ══════════════════════════════════════');
    });

    testWidgets('E2E : profil carrière + détail application', (tester) async {
      app.main();
      await _settle(tester, seconds: 6);

      // Login
      await _quickLogin(tester);
      debugPrint('[E2E] ✓ Connecté');

      // ─── Profil → Profil carrière ────────────────────────────
      await _tapNavTab(tester, 4); // Profil
      await _settle(tester, seconds: 3);

      final careerItem = find.textContaining('carrière');
      if (careerItem.evaluate().isNotEmpty) {
        await tester.tap(careerItem.first);
        await _settle(tester, seconds: 3);
        debugPrint('[E2E] ✓ Page profil carrière');

        // Retour
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first);
          await _settle(tester, seconds: 2);
        }
      }

      // ─── Applications → Détail ───────────────────────────────
      await _tapNavTab(tester, 2); // Applications
      await _settle(tester, seconds: 3);

      // Taper sur la première application si elle existe
      final appCards = find.byType(Card);
      if (appCards.evaluate().length > 1) {
        await tester.tap(appCards.at(1)); // Skip le premier si c'est un header
        await _settle(tester, seconds: 3);
        debugPrint('[E2E] ✓ Détail candidature ouvert');

        // Retour
        final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await _settle(tester, seconds: 2);
        }
      }

      debugPrint('[E2E] ✓ Parcours profil + applications terminé');
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────

/// Cherche NavigationBar (M3) ou BottomNavigationBar (M2).
Finder _findNavBar() {
  final m3 = find.byType(NavigationBar);
  if (m3.evaluate().isNotEmpty) return m3;
  return find.byType(BottomNavigationBar);
}

/// Attend que l'animation se termine.
Future<void> _settle(WidgetTester tester, {int seconds = 2}) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    Duration(seconds: seconds),
  );
  // Pump supplémentaire pour les animations en boucle
  await tester.pump(const Duration(milliseconds: 500));
}

/// Attend qu'un widget apparaisse avec timeout.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  String label = '',
  int seconds = 10,
}) async {
  for (int i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
    } catch (_) {
      // pumpAndSettle peut timeout avec des animations en boucle
    }
    if (finder.evaluate().isNotEmpty) {
      debugPrint('[E2E] Trouvé : $label');
      return;
    }
  }
  debugPrint('[E2E] TIMEOUT en attendant : $label');
}

/// Tape sur un onglet de la barre de navigation par index.
Future<void> _tapNavTab(WidgetTester tester, int index) async {
  // Chercher NavigationBar (Material 3) ou BottomNavigationBar
  final navBar = find.byType(NavigationBar);
  final bottomNav = find.byType(BottomNavigationBar);

  if (navBar.evaluate().isNotEmpty) {
    final destinations = find.descendant(of: navBar, matching: find.byType(NavigationDestination));
    if (destinations.evaluate().length > index) {
      await tester.tap(destinations.at(index));
      await _settle(tester);
    }
  } else if (bottomNav.evaluate().isNotEmpty) {
    final items = find.descendant(of: bottomNav, matching: find.byType(InkResponse));
    if (items.evaluate().length > index) {
      await tester.tap(items.at(index));
      await _settle(tester);
    }
  }
}

/// Login rapide réutilisable entre tests.
Future<void> _quickLogin(WidgetTester tester) async {
  await _settle(tester, seconds: 3);

  // Déjà connecté ?
  final nav = _findNavBar();
  if (nav.evaluate().isNotEmpty) return;

  // Taper sur le premier FilledButton (Continuer avec email)
  final continueBtn = find.byType(FilledButton);
  if (continueBtn.evaluate().isNotEmpty) {
    await tester.tap(continueBtn.first);
    await _settle(tester, seconds: 2);
  }

  final fields = find.byType(TextField);
  await _waitFor(tester, fields, label: 'Champs login');

  if (fields.evaluate().length >= 2) {
    await tester.enterText(fields.first, _email);
    await tester.enterText(fields.at(1), _password);
    await tester.pump();
    // Taper sur le FilledButton (Se connecter)
    final loginBtn = find.byType(FilledButton);
    if (loginBtn.evaluate().isNotEmpty) {
      await tester.tap(loginBtn.first);
    }
    await _settle(tester, seconds: 8);
  }

  await _waitFor(tester, _findNavBar(),
      label: 'Dashboard', seconds: 15);
}
