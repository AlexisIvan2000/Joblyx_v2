import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';

/// Écran bilan d'entretien.
class InterviewSummaryScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const InterviewSummaryScreen({super.key, required this.sessionId});

  @override
  ConsumerState<InterviewSummaryScreen> createState() => _InterviewSummaryScreenState();
}

class _InterviewSummaryScreenState extends ConsumerState<InterviewSummaryScreen> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(interviewServiceProvider);
      final session = await svc.getSession(widget.sessionId);
      if (mounted) setState(() { _session = session; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('interview.summary_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null || _session!['status'] != 'completed') {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('interview.summary_title'))),
        body: Center(child: Text(t.t('interview.summary_not_ready'))),
      );
    }

    final score = _session!['overall_score'] as int? ?? 0;
    final categoryScores = _session!['category_scores'] as Map<String, dynamic>? ?? {};
    final summary = _session!['summary'] as String? ?? '';

    // Extraire strengths, areas_to_improve, recommendation des messages feedback
    // ou du summary si stocké dans category_scores (dépend de la structure)
    // Pour l'instant on affiche ce qu'on a

    final scoreColor = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
            ? const Color(0xFFFFB347)
            : const Color(0xFFE57373);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/assistant/interview');
            }
          },
        ),
        title: Text(_session!['job_title'] as String? ?? t.t('interview.summary_title')),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          children: [
            // Score global
            SizedBox(
              width: 110.w, height: 110.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110.w, height: 110.w,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10.w,
                      color: scoreColor,
                      backgroundColor: cs.surfaceContainerHighest,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: scoreColor)),
                      Text('/100', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Scores par catégorie
            if (categoryScores.isNotEmpty)
              ...categoryScores.entries.map((e) => _CategoryBar(
                    label: _categoryLabel(e.key, t),
                    score: e.value as int? ?? 0,
                    cs: cs,
                  )),
            SizedBox(height: 16.h),

            // Résumé
            if (summary.isNotEmpty) ...[
              _SectionCard(
                title: t.t('interview.summary_section'),
                icon: Icons.summarize_outlined,
                cs: cs,
                child: Text(summary,
                    style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5)),
              ),
              SizedBox(height: 10.h),
            ],

            // Boutons
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              onPressed: () => context.push('/assistant/interview/chat/${widget.sessionId}'),
              icon: Icon(Icons.chat_outlined, size: 18.sp),
              label: Text(t.t('interview.view_conversation')),
              style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 44.h)),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String key, AppLocalizations t) {
    final labels = {
      'technical': t.t('interview.cat_technical'),
      'behavioral': t.t('interview.cat_behavioral'),
      'communication': t.t('interview.cat_communication'),
      'problem_solving': t.t('interview.cat_problem_solving'),
      'candidate_questions': t.t('interview.cat_questions'),
    };
    return labels[key] ?? key;
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int score;
  final ColorScheme cs;

  const _CategoryBar({required this.label, required this.score, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
            ? const Color(0xFFFFB347)
            : const Color(0xFFE57373);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          SizedBox(
            width: 110.w,
            child: Text(label, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8.h,
                backgroundColor: cs.surfaceContainerHighest,
                color: color,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text('$score', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.cs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18.sp, color: cs.primary),
              SizedBox(width: 8.w),
              Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ]),
            SizedBox(height: 8.h),
            child,
          ],
        ),
      ),
    );
  }
}
