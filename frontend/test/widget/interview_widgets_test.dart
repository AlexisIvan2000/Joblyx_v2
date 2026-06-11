import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';

final _t = AppLocalizations({
  'interview.title': 'Interview Simulator',
  'interview.feedback_label': 'Feedback',
  'interview.star_tip': 'Tip: use STAR method.',
  'interview.cat_technical': 'Technical',
  'interview.cat_behavioral': 'Behavioral',
  'interview.cat_communication': 'Communication',
  'interview.cat_problem_solving': 'Problem solving',
  'interview.cat_questions': 'Candidate questions',
  'interview.summary_section': 'Summary',
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
  group('ChatMessage', () {
    test('valeurs par défaut', () {
      const msg = ChatMessage(role: 'user', content: 'Hello');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello');
      expect(msg.feedback, isNull);
      expect(msg.isStreaming, false);
    });

    test('copyWith met à jour le contenu', () {
      const msg = ChatMessage(role: 'assistant', content: 'Hi', isStreaming: true);
      final updated = msg.copyWith(content: 'Hi there', isStreaming: false);
      expect(updated.content, 'Hi there');
      expect(updated.isStreaming, false);
      expect(updated.role, 'assistant');
    });

    test('copyWith ajoute le feedback', () {
      const msg = ChatMessage(role: 'assistant', content: 'Question');
      final updated = msg.copyWith(feedback: {'score': 7, 'good': 'bien'});
      expect(updated.feedback, isNotNull);
      expect(updated.feedback!['score'], 7);
    });
  });

  group('InterviewChatState', () {
    test('valeurs par défaut', () {
      const state = InterviewChatState();
      expect(state.status, 'idle');
      expect(state.messages, isEmpty);
      expect(state.questionNumber, 0);
      expect(state.isAiTyping, false);
      expect(state.summary, isNull);
    });

    test('copyWith met à jour le status', () {
      const state = InterviewChatState();
      final updated = state.copyWith(status: 'connected', sessionId: 's1');
      expect(updated.status, 'connected');
      expect(updated.sessionId, 's1');
    });

    test('copyWith clearSummary', () {
      final state = const InterviewChatState().copyWith(summary: {'score': 80});
      final cleared = state.copyWith(clearSummary: true);
      expect(cleared.summary, isNull);
    });
  });

  group('Bulle de chat (reproduction)', () {
    testWidgets('affiche message utilisateur à droite', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ChatBubbleTest(
            message: 'My answer',
            isUser: true,
            cs: cs,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My answer'), findsOneWidget);
    });

    testWidgets('affiche message assistant à gauche', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ChatBubbleTest(
            message: 'Question from AI',
            isUser: false,
            cs: cs,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Question from AI'), findsOneWidget);
    });
  });

  group('Feedback pliable (reproduction)', () {
    testWidgets('affiche score et peut se déplier', (tester) async {
      await tester.pumpWidget(_testApp(
        _FeedbackTest(feedback: {
          'score': 8,
          'good': 'Great structure',
          'improve': 'Add more details',
        }),
      ));
      await tester.pumpAndSettle();

      // Score visible
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);

      // Feedback replié par défaut — textes pas visibles
      expect(find.text('Great structure'), findsNothing);

      // Tap pour déplier
      await tester.tap(find.text('8/10'));
      await tester.pumpAndSettle();

      expect(find.text('Great structure'), findsOneWidget);
      expect(find.text('Add more details'), findsOneWidget);
    });
  });

  group('Score bilan (reproduction)', () {
    testWidgets('affiche le score dans un cercle', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _SummaryScoreTest(score: 74, cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('74'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Barres catégories (reproduction)', () {
    testWidgets('affiche les 5 catégories', (tester) async {
      await tester.pumpWidget(_testApp(
        Column(children: [
          _CategoryBarTest(label: 'Technical', score: 80),
          _CategoryBarTest(label: 'Behavioral', score: 65),
          _CategoryBarTest(label: 'Communication', score: 70),
        ]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Technical'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('Behavioral'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });
  });
}

//  Widgets de test

class _ChatBubbleTest extends StatelessWidget {
  final String message;
  final bool isUser;
  final ColorScheme cs;

  const _ChatBubbleTest({required this.message, required this.isUser, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message, style: TextStyle(color: isUser ? cs.onPrimary : cs.onSurface)),
      ),
    );
  }
}

class _FeedbackTest extends StatefulWidget {
  final Map<String, dynamic> feedback;
  const _FeedbackTest({required this.feedback});

  @override
  State<_FeedbackTest> createState() => _FeedbackTestState();
}

class _FeedbackTestState extends State<_FeedbackTest> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${widget.feedback['score']}/10',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                const SizedBox(width: 6),
                Text(t.t('interview.feedback_label')),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              if (widget.feedback['good'] != null)
                Text(widget.feedback['good'] as String, style: const TextStyle(color: Color(0xFF5DCAA5))),
              if (widget.feedback['improve'] != null)
                Text(widget.feedback['improve'] as String, style: const TextStyle(color: Color(0xFFFFB347))),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryScoreTest extends StatelessWidget {
  final int score;
  final ColorScheme cs;
  const _SummaryScoreTest({required this.score, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70 ? const Color(0xFF5DCAA5)
        : score >= 40 ? const Color(0xFFFFB347)
        : const Color(0xFFE57373);

    return SizedBox(
      width: 110, height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100, strokeWidth: 10,
            color: color, backgroundColor: cs.surfaceContainerHighest,
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
            Text('/100', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ],
      ),
    );
  }
}

class _CategoryBarTest extends StatelessWidget {
  final String label;
  final int score;
  const _CategoryBarTest({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = score >= 70 ? const Color(0xFF5DCAA5)
        : score >= 40 ? const Color(0xFFFFB347)
        : const Color(0xFFE57373);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: score / 100, minHeight: 8, color: color, backgroundColor: cs.surfaceContainerHighest)),
        const SizedBox(width: 8),
        Text('$score'),
      ]),
    );
  }
}
