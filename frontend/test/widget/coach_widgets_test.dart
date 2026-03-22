import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';

final _t = AppLocalizations({
  'assistant.title': 'Assistant',
  'assistant.coach_title': 'Optimize my CV',
  'assistant.coach_subtitle': 'Analyze your CV against a job posting',
  'assistant.simulator_title': 'Interview simulator',
  'assistant.simulator_subtitle': 'Practice with an AI recruiter',
  'assistant.coming_soon': 'Coming soon',
  'assistant.recent_history': 'Recent history',
  'assistant.no_history': 'No analysis yet',
  'assistant.result_title': 'CV Analysis',
  'coach.ats_title': 'ATS Keywords',
  'coach.keyword_match': 'Keyword match',
  'coach.keywords_found': 'Found',
  'coach.keywords_missing': 'Missing',
  'coach.structure_title': 'CV Structure',
  'coach.experience_title': 'Experience Optimization',
  'coach.strengths_title': 'Strengths',
  'coach.recommendations_title': 'Recommendations',
  'coach.missing_sections_title': 'Missing Sections',
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
  group('CoachAnalysisState', () {
    test('valeurs par défaut', () {
      const state = CoachAnalysisState();
      expect(state.status, 'idle');
      expect(state.streamingText, isEmpty);
      expect(state.analysis, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith met à jour les champs', () {
      const state = CoachAnalysisState();
      final updated = state.copyWith(
        status: 'analyzing',
        streamingText: 'some text',
        analysis: {'compatibility_score': 75},
      );
      expect(updated.status, 'analyzing');
      expect(updated.streamingText, 'some text');
      expect(updated.analysis!['compatibility_score'], 75);
    });

    test('copyWith clearAnalysis met analysis à null', () {
      final state = const CoachAnalysisState().copyWith(
        analysis: {'score': 50},
      );
      final cleared = state.copyWith(clearAnalysis: true);
      expect(cleared.analysis, isNull);
    });
  });

  group('Score circulaire (reproduction)', () {
    testWidgets('affiche le score et le pourcentage', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ScoreTest(score: 72, cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('72'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('score < 40 utilise rouge', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ScoreTest(score: 25, cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
    });
  });

  group('Section ATS (reproduction)', () {
    testWidgets('affiche les keywords trouvés et manquants', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          return _AtsTest(ats: {
            'keywords_found': ['Python', 'Docker'],
            'keywords_missing': ['Kubernetes'],
            'keyword_match_percentage': 65,
            'ats_tips': ['Use exact job title'],
          });
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Docker'), findsOneWidget);
      expect(find.text('Kubernetes'), findsOneWidget);
      expect(find.textContaining('65%'), findsOneWidget);
      expect(find.text('Use exact job title'), findsOneWidget);
    });
  });

  group('Section Recommandations (reproduction)', () {
    testWidgets('affiche les badges de priorité', (tester) async {
      await tester.pumpWidget(_testApp(
        _RecommendationsTest(items: [
          {'priority': 'critical', 'title': 'Add keywords', 'problem': 'Missing ATS words'},
          {'priority': 'high', 'title': 'Quantify results', 'problem': 'No metrics'},
          {'priority': 'medium', 'title': 'Add summary', 'problem': 'No summary section'},
        ]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('Add keywords'), findsOneWidget);
    });
  });

  group('Carte historique assistant (reproduction)', () {
    testWidgets('affiche le score, titre et date', (tester) async {
      await tester.pumpWidget(_testApp(
        _HistoryTileTest(session: {
          'id': 's1',
          'job_title': 'Flutter Developer',
          'company_name': 'Google',
          'compatibility_score': 85,
          'created_at': '2026-03-20T10:00:00',
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('85'), findsOneWidget);
      expect(find.text('Flutter Developer'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('20/03/2026'), findsOneWidget);
    });
  });
}

// ── Widgets de test ──────────────────────────────────────────

class _ScoreTest extends StatelessWidget {
  final int score;
  final ColorScheme cs;
  const _ScoreTest({required this.score, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
            ? const Color(0xFFFFB347)
            : const Color(0xFFE57373);

    return SizedBox(
      width: 100, height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            color: color,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
              Text('%', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtsTest extends StatelessWidget {
  final Map<String, dynamic> ats;
  const _AtsTest({required this.ats});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final found = (ats['keywords_found'] as List?)?.cast<String>() ?? [];
    final missing = (ats['keywords_missing'] as List?)?.cast<String>() ?? [];
    final matchPct = ats['keyword_match_percentage'] as int? ?? 0;
    final tips = (ats['ats_tips'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${t.t('coach.keyword_match')}: $matchPct%'),
        Wrap(children: found.map((k) => Padding(padding: const EdgeInsets.all(2), child: Text(k))).toList()),
        Wrap(children: missing.map((k) => Padding(padding: const EdgeInsets.all(2), child: Text(k))).toList()),
        ...tips.map((tip) => Text(tip)),
      ],
    );
  }
}

class _RecommendationsTest extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _RecommendationsTest({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((i) {
        final priority = i['priority'] as String;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(priority.toUpperCase()),
              Text(i['title'] as String),
              if (i['problem'] != null) Text(i['problem'] as String),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HistoryTileTest extends StatelessWidget {
  final Map<String, dynamic> session;
  const _HistoryTileTest({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = session['compatibility_score'] as int? ?? 0;
    final jobTitle = session['job_title'] as String? ?? '';
    final company = session['company_name'] as String? ?? '';
    final createdAt = session['created_at'] as String? ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    return Row(
      children: [
        Text('$score'),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(jobTitle),
              Text(company),
            ],
          ),
        ),
        Text(dateStr),
      ],
    );
  }
}
