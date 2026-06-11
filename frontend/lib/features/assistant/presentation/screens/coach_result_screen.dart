import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/assistant/presentation/widgets/coach_sections.dart';

/// Écran résultat coach IA — affiché pendant et après le streaming.
class CoachResultScreen extends ConsumerStatefulWidget {
  const CoachResultScreen({super.key});

  @override
  ConsumerState<CoachResultScreen> createState() => _CoachResultScreenState();
}

class _CoachResultScreenState extends ConsumerState<CoachResultScreen> {
  @override
  void dispose() {
    // Annule le streaming si l'utilisateur quitte avant la fin, pour ne pas gaspiller de tokens
    if (ref.read(coachAnalysisProvider).status == 'analyzing') {
      ref.read(coachAnalysisProvider.notifier).cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(coachAnalysisProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('assistant.result_title'))),
      body: _buildBody(context, cs, t, state),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, AppLocalizations t, CoachAnalysisState state) {
    if (state.status == 'error') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48.sp, color: cs.error),
            SizedBox(height: 12.h),
            Text(t.t('assistant.analyze_error'),
                style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Analyse terminée — afficher le résultat complet
    if (state.status == 'done' && state.analysis != null) {
      return CoachAnalysisView(analysis: state.analysis!, isStreaming: false);
    }

    // En cours de streaming
    if (state.status == 'analyzing') {
      return _buildStreaming(cs, t, state);
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildStreaming(ColorScheme cs, AppLocalizations t, CoachAnalysisState state) {
    final analysis = state.analysis;
    final hasScore = analysis != null && analysis.containsKey('compatibility_score');

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        // En-tête : titre + barre de progression
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Column(
            children: [
              Text(t.t('assistant.analyzing_title'),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: cs.onSurface),
                  textAlign: TextAlign.center),
              SizedBox(height: 6.h),
              Text(t.t('assistant.analyzing_subtitle'),
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              SizedBox(height: 12.h),
              SizedBox(
                width: 180.w,
                child: LinearProgressIndicator(borderRadius: BorderRadius.circular(4.r)),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Score si déjà parsé
        if (hasScore) ...[
          CoachScoreWidget(score: analysis['compatibility_score'] as int? ?? 0),
          SizedBox(height: 8.h),
          if (analysis.containsKey('summary'))
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                analysis['summary'] as String? ?? '',
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(height: 16.h),
        ],

        // Texte brut du streaming
        if (state.streamingText.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: hasScore ? 200.h : 300.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                state.streamingText,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),

        // Shimmer placeholders
        if (!hasScore) ...[
          SizedBox(height: 20.h),
          _shimmerCircle(cs),
          SizedBox(height: 16.h),
        ],
        ..._shimmerCards(cs, hasScore ? 2 : 3),

        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _shimmerCircle(ColorScheme cs) {
    return Center(
      child: ShimmerLoading(
        child: Container(
          width: 100.w, height: 100.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }

  List<Widget> _shimmerCards(ColorScheme cs, int count) {
    return List.generate(count, (i) => Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: ShimmerLoading(
        child: Container(
          height: 56.h, width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    ));
  }
}
