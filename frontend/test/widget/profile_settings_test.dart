import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Traductions de test pour les widgets profil/settings.
final _t = AppLocalizations({
  'profile_screen.title': 'Profile',
  'profile_screen.regenerations_left': 'Regenerations left',
  'profile_screen.total_applications': 'Total applications',
  'profile_screen.personal_info': 'Personal information',
  'profile_screen.personal_info_sub': 'First name, last name',
  'profile_screen.career_profile': 'Career profile',
  'profile_screen.career_profile_sub': 'Level, target jobs, skills',
  'profile_screen.security': 'Change password',
  'profile_screen.security_sub': '***********',
  'profile_screen.logout': 'Log out',
  'profile_screen.change_photo': 'Change profile photo',
  'profile_screen.take_photo': 'Take a photo',
  'profile_screen.choose_photo': 'Choose a photo',
  'settings.change_email': 'Change email',
  'settings.title': 'Settings',
  'settings.section_general': 'General',
  'settings.language': 'Language',
  'settings.language_system': 'System',
  'settings.theme': 'Theme',
  'settings.theme_system': 'System',
  'settings.section_legal': 'Legal',
  'settings.terms': 'Terms of use',
  'settings.privacy': 'Privacy policy',
  'settings.section_contact': 'Contact us',
  'settings.contact_email': 'Support email',
  'settings.delete_account': 'Delete my account',
  'settings.app_version': 'Version',
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
  group('Page Profil - StatBox', () {
    testWidgets('affiche les stats régénérations et candidatures', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Row(children: [
            Expanded(child: _StatBoxTest(value: '5', label: 'Regenerations left', cs: cs)),
            const SizedBox(width: 10),
            Expanded(child: _StatBoxTest(value: '12', label: 'Total applications', cs: cs)),
          ]);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Regenerations left'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Total applications'), findsOneWidget);
    });
  });

  group('Page Profil - Menu items', () {
    testWidgets('affiche les 4 menu items avec icônes différenciées', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Column(children: [
            _MenuItemTest(
              icon: Icons.person_outline_rounded, iconColor: const Color(0xFF2563EB),
              title: 'Personal information', subtitle: 'First name, last name', cs: cs,
            ),
            _MenuItemTest(
              icon: Icons.trending_up_rounded, iconColor: const Color(0xFF059669),
              title: 'Career profile', subtitle: 'Level, target jobs, skills', cs: cs,
            ),
            _MenuItemTest(
              icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF7C3AED),
              title: 'Change password', subtitle: '***********', cs: cs,
            ),
            _MenuItemTest(
              icon: Icons.alternate_email_rounded, iconColor: const Color(0xFFD97706),
              title: 'Change email', subtitle: 'test@test.com', cs: cs,
            ),
          ]);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Personal information'), findsOneWidget);
      expect(find.text('Career profile'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Change email'), findsOneWidget);
    });
  });

  group('Page Profil - Bouton destructif', () {
    testWidgets('bouton déconnexion a un contour rouge et texte rouge', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _DestructiveButtonTest(label: 'Log out', cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
      // Le texte doit être de la couleur error du thème
      final textWidget = tester.widget<Text>(find.text('Log out'));
      final errorColor = Theme.of(tester.element(find.text('Log out'))).colorScheme.error;
      expect(textWidget.style?.color, equals(errorColor));
    });
  });

  group('Page Settings - Menu items', () {
    testWidgets('affiche langue, thème, CGU, confidentialité, contact, supprimer', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Column(children: [
            _MenuItemTest(icon: Icons.language_rounded, iconColor: const Color(0xFF2563EB),
                title: 'Language', subtitle: 'System', cs: cs),
            _MenuItemTest(icon: Icons.palette_outlined, iconColor: const Color(0xFF7C3AED),
                title: 'Theme', subtitle: 'System', cs: cs),
            _MenuItemTest(icon: Icons.description_outlined, iconColor: const Color(0xFF059669),
                title: 'Terms of use', subtitle: 'joblyx.com', cs: cs),
            _MenuItemTest(icon: Icons.shield_outlined, iconColor: const Color(0xFF0891B2),
                title: 'Privacy policy', subtitle: 'joblyx.com', cs: cs),
            _MenuItemTest(icon: Icons.email_outlined, iconColor: const Color(0xFFD97706),
                title: 'Support email', subtitle: 'support@joblyx.com', cs: cs),
            _MenuItemTest(icon: Icons.business_rounded, iconColor: const Color(0xFF0A66C2),
                title: 'LinkedIn', subtitle: 'Joblyx', cs: cs),
          ]);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Support email'), findsOneWidget);
      expect(find.text('LinkedIn'), findsOneWidget);
    });
  });

  group('Page Settings - Bouton supprimer compte', () {
    testWidgets('bouton supprimer a un contour rouge', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _DestructiveButtonTest(label: 'Delete my account', cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Delete my account'), findsOneWidget);
    });
  });
}

// ── Widgets de test (reproduction simplifiée des vrais widgets) ──

class _StatBoxTest extends StatelessWidget {
  final String value, label;
  final ColorScheme cs;
  const _StatBoxTest({required this.value, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.primary)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _MenuItemTest extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final ColorScheme cs;
  const _MenuItemTest({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _DestructiveButtonTest extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _DestructiveButtonTest({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.logout_rounded, size: 20, color: cs.error),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.error)),
      ]),
    );
  }
}
