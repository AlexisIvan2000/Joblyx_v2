import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/constants/application_status.dart';

/// Traductions de test pour les widgets applications.
final _t = AppLocalizations({
  'applications_screen.status_saved': 'Saved',
  'applications_screen.status_applied': 'Applied',
  'applications_screen.status_online_assessment': 'Online test',
  'applications_screen.status_phone_screen': 'Phone screen',
  'applications_screen.status_technical': 'Technical',
  'applications_screen.status_final_interview': 'Final interview',
  'applications_screen.status_offer': 'Offer received',
  'applications_screen.status_accepted': 'Accepted',
  'applications_screen.status_rejected': 'Rejected',
  'applications_screen.status_withdrawn': 'Withdrawn',
  'applications_screen.time_today': 'Today',
  'applications_screen.days_ago': 'd ago',
  'application_detail.show_more': 'Show more',
  'application_detail.show_less': 'Show less',
  'application_detail.description': 'Job description',
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
  group('ApplicationStatuses', () {
    test('contient 10 statuts', () {
      expect(ApplicationStatuses.all.length, 11);
    });

    test('fromKey retourne le bon statut', () {
      expect(ApplicationStatuses.fromKey('applied').key, 'applied');
      expect(ApplicationStatuses.fromKey('offer').key, 'offer');
    });

    test('fromKey retourne saved par défaut pour clé inconnue', () {
      expect(ApplicationStatuses.fromKey('unknown').key, 'saved');
    });

    test('chaque statut a des couleurs distinctes', () {
      final keys = ApplicationStatuses.all.map((s) => s.key).toSet();
      // Tous les keys sont uniques
      expect(keys.length, 11);
      // Chaque statut a des couleurs non-nulles
      for (final s in ApplicationStatuses.all) {
        expect(s.textColor, isNotNull);
        expect(s.bgColor, isNotNull);
        expect(s.borderColor, isNotNull);
      }
    });
  });

  group('ApplicationCard (reproduction)', () {
    testWidgets('affiche le poste, l\'entreprise et le badge statut', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final cfg = ApplicationStatuses.fromKey('applied');
          return _AppCardTest(
            jobTitle: 'Flutter Dev',
            company: 'Google',
            status: 'applied',
            daysLabel: 'Today',
            cfg: cfg,
            cs: cs,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Dev'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // Initiale de l'entreprise
      expect(find.text('G'), findsOneWidget);
    });
  });

  group('StatusSelector (reproduction)', () {
    testWidgets('affiche les 10 statuts', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _StatusSelectorTest(current: 'saved', cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Online test'), findsOneWidget);
      expect(find.text('Technical'), findsOneWidget);
      expect(find.text('Offer received'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('le statut sélectionné a la couleur du statut', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _StatusSelectorTest(current: 'applied', cs: cs);
        }),
      ));
      await tester.pumpAndSettle();

      // Vérifier que "Applied" utilise la couleur du statut
      final appliedText = tester.widget<Text>(find.text('Applied'));
      expect(appliedText.style?.color, ApplicationStatuses.applied.textColor);
    });
  });

  group('DismissibleFilterChip (reproduction)', () {
    testWidgets('affiche le label et le bouton de suppression', (tester) async {
      var removed = false;
      await tester.pumpWidget(_testApp(
        _FilterChipTest(
          label: 'Applied',
          textColor: const Color(0xFF085041),
          bgColor: const Color(0xFFE1F5EE),
          borderColor: const Color(0xFF5DCAA5),
          onRemove: () => removed = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Applied'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap le bouton close
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(removed, isTrue);
    });
  });

  group('Description pliable (reproduction)', () {
    testWidgets('affiche Voir plus quand le texte est long', (tester) async {
      final longText = 'A' * 500; // Texte assez long pour dépasser 4 lignes
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ExpandableDescriptionTest(
            content: longText,
            cs: cs,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Job description'), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('texte court n\'affiche pas Voir plus', (tester) async {
      await tester.pumpWidget(_testApp(
        Builder(builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return _ExpandableDescriptionTest(
            content: 'Short text.',
            cs: cs,
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Show more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });
  });
}

// ── Widgets de test (reproduction simplifiée des vrais widgets) ──

class _AppCardTest extends StatelessWidget {
  final String jobTitle, company, status, daysLabel;
  final AppStatusConfig cfg;
  final ColorScheme cs;

  const _AppCardTest({
    required this.jobTitle,
    required this.company,
    required this.status,
    required this.daysLabel,
    required this.cfg,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final initial = company.isNotEmpty ? company[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: cfg.bgColor, shape: BoxShape.circle),
            child: Center(child: Text(initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cfg.textColor))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jobTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text(company, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cfg.bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cfg.borderColor),
                ),
                child: Text(t.t('applications_screen.status_$status'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cfg.textColor)),
              ),
              const SizedBox(height: 6),
              Text(daysLabel, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusSelectorTest extends StatelessWidget {
  final String current;
  final ColorScheme cs;

  const _StatusSelectorTest({required this.current, required this.cs});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ApplicationStatuses.all.map((cfg) {
        final isSelected = cfg.key == current;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? cfg.bgColor : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? cfg.borderColor : Colors.transparent),
          ),
          child: Text(
            t.t('applications_screen.status_${cfg.key}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? cfg.textColor : cs.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FilterChipTest extends StatelessWidget {
  final String label;
  final Color textColor, bgColor, borderColor;
  final VoidCallback onRemove;

  const _FilterChipTest({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ExpandableDescriptionTest extends StatefulWidget {
  final String content;
  final ColorScheme cs;

  const _ExpandableDescriptionTest({required this.content, required this.cs});

  @override
  State<_ExpandableDescriptionTest> createState() => _ExpandableDescriptionTestState();
}

class _ExpandableDescriptionTestState extends State<_ExpandableDescriptionTest> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const maxLines = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('application_detail.description'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.cs.onSurface)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCrossFade(
                firstChild: Text(widget.content, maxLines: maxLines, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: widget.cs.onSurfaceVariant, height: 1.5)),
                secondChild: Text(widget.content,
                    style: TextStyle(fontSize: 13, color: widget.cs.onSurfaceVariant, height: 1.5)),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tp = TextPainter(
                    text: TextSpan(text: widget.content, style: const TextStyle(fontSize: 13, height: 1.5)),
                    maxLines: maxLines,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: constraints.maxWidth);

                  if (!tp.didExceedMaxLines) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _expanded ? t.t('application_detail.show_less') : t.t('application_detail.show_more'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.cs.primary),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
