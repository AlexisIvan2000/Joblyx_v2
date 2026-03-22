import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/assistant/presentation/widgets/coach_sections.dart';

/// Écran résultat coach IA — affiché pendant et après le streaming.
class CoachResultScreen extends ConsumerWidget {
  const CoachResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text(t.t('assistant.analyze_error'), style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    final analysis = state.analysis;

    if (state.status == 'analyzing' && analysis == null) {
      // Shimmer pendant le chargement initial
      return _buildShimmer(cs);
    }

    if (analysis == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CoachAnalysisView(
      analysis: analysis,
      isStreaming: state.status == 'analyzing',
    );
  }

  Widget _buildShimmer(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: ShimmerLoading(
        child: Column(
          children: [
            // Score placeholder
            Container(
              width: 100.w, height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest,
              ),
            ),
            SizedBox(height: 20.h),
            Container(height: 16.h, width: 240.w, color: cs.surfaceContainerHighest),
            SizedBox(height: 12.h),
            Container(height: 12.h, width: 300.w, color: cs.surfaceContainerHighest),
            SizedBox(height: 24.h),
            ...List.generate(3, (i) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(height: 60.h, width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
