import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/dashboard_widgets.dart';

/// Test translations — flat map matching the app's i18n keys.
final _translations = AppLocalizations({
  'home.progress_title': 'ROADMAP PROGRESS',
  'home.actions_label': 'actions',
  'home.skills_acquired': 'skills acquired',
  'home.weeks_label': 'weeks',
  'home.empty_roadmap_title': 'Ready to plan your career?',
  'home.empty_roadmap_subtitle': 'Create your personalized roadmap.',
  'home.generate_ai': 'Generate with AI',
  'home.create_manual': 'Create manually',
  'home.empty_applications_title': 'No applications yet',
  'home.empty_applications_subtitle': 'Start tracking your applications.',
  'home.add_application': 'Add an application',
  'home.phase_label': 'PHASE',
  'applications_screen.status_applied': 'Applied',
});

/// Custom delegate that returns pre-built translations (no asset loading).
class _TestLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) async => _translations;
  @override
  bool shouldReload(_) => false;
}

/// Wraps a widget in MaterialApp with i18n + ScreenUtil for testing.
Widget _testApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [_TestLocalizationsDelegate()],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('EmptyRoadmapCard', () {
    testWidgets('displays title and both CTA buttons', (tester) async {
      bool aiTapped = false;
      bool manualTapped = false;

      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final t = AppLocalizations.of(context);
          return SingleChildScrollView(
            child: EmptyRoadmapCard(
              cs: cs,
              t: t,
              onGenerateAI: () => aiTapped = true,
              onCreateManual: () => manualTapped = true,
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ready to plan your career?'), findsOneWidget);
      expect(find.text('Generate with AI'), findsOneWidget);
      expect(find.text('Create manually'), findsOneWidget);

      await tester.tap(find.text('Generate with AI'));
      expect(aiTapped, true);

      await tester.tap(find.text('Create manually'));
      expect(manualTapped, true);
    });

    testWidgets('displays subtitle text', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final t = AppLocalizations.of(context);
          return SingleChildScrollView(
            child: EmptyRoadmapCard(
              cs: cs,
              t: t,
              onGenerateAI: () {},
              onCreateManual: () {},
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Create your personalized roadmap.'), findsOneWidget);
    });
  });

  group('EmptyApplicationsCard', () {
    testWidgets('displays title, subtitle, and CTA button', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final t = AppLocalizations.of(context);
          return EmptyApplicationsCard(
            cs: cs,
            t: t,
            onTap: () => tapped = true,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No applications yet'), findsOneWidget);
      expect(find.text('Start tracking your applications.'), findsOneWidget);
      expect(find.text('Add an application'), findsOneWidget);

      await tester.tap(find.text('Add an application'));
      expect(tapped, true);
    });
  });

  group('ProgressCard', () {
    testWidgets('displays progress info correctly', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final t = AppLocalizations.of(context);
          return SingleChildScrollView(
            child: ProgressCard(
              actionPercent: 60,
              completedActions: 6,
              totalActions: 10,
              completedSkills: 3,
              totalSkills: 5,
              totalWeeks: 12,
              cs: cs,
              t: t,
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ROADMAP PROGRESS'), findsOneWidget);
      expect(find.text('6/10 actions'), findsOneWidget);
      expect(find.text('3/5 skills acquired · ~12 weeks'), findsOneWidget);
    });

    testWidgets('displays 0% when no actions', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final t = AppLocalizations.of(context);
          return SingleChildScrollView(
            child: ProgressCard(
              actionPercent: 0,
              completedActions: 0,
              totalActions: 0,
              completedSkills: 0,
              totalSkills: 0,
              totalWeeks: 0,
              cs: cs,
              t: t,
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('0/0 actions'), findsOneWidget);
    });
  });

  group('StatCard', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(_testApp(
        const Row(children: [
          StatCard(
            value: '5',
            label: 'Active',
            icon: '\u{1F4CB}',
            color: Color(0xFF2563EB),
          ),
        ]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
