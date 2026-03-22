import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';

/// Traductions de test pour les widgets roadmap.
final _t = AppLocalizations({
  'dashboard.title': 'My Roadmap',
  'dashboard.generating_title': 'Building your roadmap...',
  'dashboard.generating_subtitle': 'AI is analyzing your profile.',
  'dashboard.congrats_title': 'Congratulations!',
  'dashboard.congrats_subtitle': 'You completed all phases.',
  'dashboard.congrats_ai': 'New with AI',
  'dashboard.congrats_manual': 'New manual',
  'dashboard.menu_regenerate': 'Regenerate with AI',
  'dashboard.menu_manual': 'New manual roadmap',
  'dashboard.menu_archive': 'Archive this roadmap',
  'dashboard.history': 'History',
  'dashboard.history_created': 'Created on',
  'dashboard.history_more_phases': 'more phase(s)',
  'dashboard.history_empty': 'No roadmap history',
  'dashboard.history_delete': 'Delete this roadmap',
  'dashboard.history_delete_all': 'Delete all',
  'dashboard.empty_title': 'No roadmap yet',
  'dashboard.phases_label': 'Phases',
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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('RoadmapState', () {
    test('valeurs par défaut', () {
      const state = RoadmapState();
      expect(state.isLoading, true);
      expect(state.generationStatus, 'idle');
      expect(state.hasRoadmap, false);
      expect(state.roadmap, isNull);
      expect(state.streamingText, isEmpty);
      expect(state.streamingPhases, isEmpty);
    });

    test('copyWith met à jour les champs', () {
      const state = RoadmapState();
      final updated = state.copyWith(
        isLoading: false,
        generationStatus: 'generating',
        hasRoadmap: true,
        streamingText: 'abc',
        streamingPhases: [{'title': 'Phase 1'}],
      );

      expect(updated.isLoading, false);
      expect(updated.generationStatus, 'generating');
      expect(updated.hasRoadmap, true);
      expect(updated.streamingText, 'abc');
      expect(updated.streamingPhases.length, 1);
    });

    test('copyWith clearRoadmap met roadmap à null', () {
      final state = const RoadmapState().copyWith(
        roadmap: {'id': 'r1'},
        hasRoadmap: true,
      );
      final cleared = state.copyWith(clearRoadmap: true);
      expect(cleared.roadmap, isNull);
    });
  });

  group('Parsing progressif JSON', () {
    // Tester la logique de parsing des phases depuis du JSON partiel
    test('extrait les phases complètes du buffer', () {
      final buffer = '''
        {"summary": {"overview": "Test"},
         "phases": [
           {"title": "Phase 1", "duration_weeks": 4, "objective": "Learn basics"},
           {"title": "Phase 2", "duration_weeks": 3, "objective": "Build project"}
         ]}
      ''';

      final phases = _extractPhases(buffer);
      expect(phases.length, 2);
      expect(phases[0]['title'], 'Phase 1');
      expect(phases[1]['title'], 'Phase 2');
    });

    test('extrait les phases même avec JSON partiel après', () {
      // Simule un buffer où la 3ème phase est incomplète
      final buffer = '''
        {"phases": [
           {"title": "Phase 1", "duration_weeks": 4},
           {"title": "Phase 2", "duration_weeks": 3},
           {"title": "Phase 3", "dur
      ''';

      final phases = _extractPhases(buffer);
      expect(phases.length, 2); // Seulement les 2 complètes
    });

    test('retourne vide si pas de "phases" dans le buffer', () {
      final buffer = '{"summary": {"overview": "building..."';
      final phases = _extractPhases(buffer);
      expect(phases, isEmpty);
    });

    test('retourne vide si le tableau phases n\'a pas commencé', () {
      final buffer = '{"summary": {}, "phases":';
      final phases = _extractPhases(buffer);
      expect(phases, isEmpty);
    });

    test('gère les strings avec accolades internes', () {
      final buffer = '''
        {"phases": [
           {"title": "Learn {React}", "objective": "Build {apps}"}
         ]}
      ''';
      final phases = _extractPhases(buffer);
      expect(phases.length, 1);
      expect(phases[0]['title'], 'Learn {React}');
    });
  });

  group('Carte de félicitations (reproduction)', () {
    testWidgets('affiche le titre et les 2 boutons quand toutes les phases complétées', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return SingleChildScrollView(
            child: _CongratsCard(cs: cs),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('You completed all phases.'), findsOneWidget);
      expect(find.text('New with AI'), findsOneWidget);
      expect(find.text('New manual'), findsOneWidget);
    });
  });

  group('Carte historique (reproduction)', () {
    testWidgets('affiche la date, les titres de phases et la barre de progression', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _HistoryCardTest(
            cs: cs,
            item: {
              'created_at': '2026-03-15T10:00:00',
              'phases': [
                {'title': 'Learn Flutter', 'completed': true},
                {'title': 'Build Portfolio', 'completed': true},
                {'title': 'Apply for Jobs', 'completed': false},
              ],
            },
          );
        }),
      ));
      await tester.pumpAndSettle();

      // Date
      expect(find.textContaining('15/03/2026'), findsOneWidget);
      // Titres des phases
      expect(find.text('Learn Flutter'), findsOneWidget);
      expect(find.text('Build Portfolio'), findsOneWidget);
      expect(find.text('Apply for Jobs'), findsOneWidget);
      // Ratio
      expect(find.text('2/3'), findsOneWidget);
      // Barre de progression
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche "+N phase(s) de plus" quand plus de 3 phases', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _HistoryCardTest(
            cs: cs,
            item: {
              'created_at': '2026-01-01T10:00:00',
              'phases': [
                {'title': 'Phase 1', 'completed': false},
                {'title': 'Phase 2', 'completed': false},
                {'title': 'Phase 3', 'completed': false},
                {'title': 'Phase 4', 'completed': false},
                {'title': 'Phase 5', 'completed': false},
              ],
            },
          );
        }),
      ));
      await tester.pumpAndSettle();

      // Seulement 3 titres affichés
      expect(find.text('Phase 1'), findsOneWidget);
      expect(find.text('Phase 2'), findsOneWidget);
      expect(find.text('Phase 3'), findsOneWidget);
      expect(find.text('Phase 4'), findsNothing);
      // "+2 more phase(s)"
      expect(find.textContaining('+2'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
    });
  });

  group('PopupMenuButton roadmap (reproduction)', () {
    testWidgets('affiche les 3 options du menu', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (_) {},
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'regenerate',
                child: Text('Regenerate with AI'),
              ),
              PopupMenuItem(
                value: 'manual',
                child: Text('New manual roadmap'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text('Archive this roadmap'),
              ),
            ],
          );
        }),
      ));
      await tester.pumpAndSettle();

      // Ouvrir le menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Regenerate with AI'), findsOneWidget);
      expect(find.text('New manual roadmap'), findsOneWidget);
      expect(find.text('Archive this roadmap'), findsOneWidget);
    });
  });
}

// ── Helpers ────────────────────────────────────────────────────

/// Reproduit la logique de parsing progressif du provider.
List<Map<String, dynamic>> _extractPhases(String buffer) {
  final phasesStart = buffer.indexOf('"phases"');
  if (phasesStart == -1) return [];

  final bracketStart = buffer.indexOf('[', phasesStart);
  if (bracketStart == -1) return [];

  final content = buffer.substring(bracketStart + 1);
  final phases = <Map<String, dynamic>>[];
  int depth = 0;
  int objStart = -1;
  bool inString = false;
  bool escaped = false;

  for (int i = 0; i < content.length; i++) {
    final c = content[i];
    if (escaped) { escaped = false; continue; }
    if (c == '\\') { escaped = true; continue; }
    if (c == '"') { inString = !inString; continue; }
    if (inString) continue;

    if (c == '{') {
      if (depth == 0) objStart = i;
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0 && objStart != -1) {
        final objStr = content.substring(objStart, i + 1);
        try {
          final parsed = jsonDecode(objStr) as Map<String, dynamic>;
          phases.add(parsed);
        } catch (_) {}
        objStart = -1;
      }
    }
  }
  return phases;
}

// ── Widgets de test ────────────────────────────────────────────

class _CongratsCard extends StatelessWidget {
  final ColorScheme cs;
  const _CongratsCard({required this.cs});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_rounded, size: 40, color: cs.primary),
          const SizedBox(height: 10),
          Text(t.t('dashboard.congrats_title'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(t.t('dashboard.congrats_subtitle')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(t.t('dashboard.congrats_ai')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(t.t('dashboard.congrats_manual')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCardTest extends StatelessWidget {
  final ColorScheme cs;
  final Map<String, dynamic> item;
  const _HistoryCardTest({required this.cs, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final createdAt = item['created_at'] as String? ?? '';
    final phases = (item['phases'] as List?) ?? [];
    final phaseCount = phases.length;
    final completedCount = phases
        .where((p) => (p as Map<String, dynamic>)['completed'] == true)
        .length;
    final progress = phaseCount > 0 ? completedCount / phaseCount : 0.0;
    final phaseTitles = phases
        .take(3)
        .map((p) => (p as Map<String, dynamic>)['title'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14),
                const SizedBox(width: 6),
                if (dateStr.isNotEmpty)
                  Text('${t.t('dashboard.history_created')} $dateStr'),
              ],
            ),
            const SizedBox(height: 10),
            ...phaseTitles.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )),
            if (phaseCount > 3)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text('+${phaseCount - 3} ${t.t('dashboard.history_more_phases')}'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(width: 10),
                Text('$completedCount/$phaseCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
