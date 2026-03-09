import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase_card.dart';

class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    final state = ref.watch(roadmapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('dashboard.title')),
        actions: [
          if (state.hasRoadmap && state.generationStatus != 'generating')
            IconButton(
              onPressed: () => _regenerate(context, ref, t),
              icon: Icon(Icons.refresh_rounded, size: 22.sp),
              tooltip: t.t('dashboard.regenerate'),
            ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, size: 22.sp),
          ),
        ],
      ),
      body: state.isLoading
          ? const RoadmapSkeleton()
          : _buildBody(context, ref, theme, cs, t, state),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref, AppLocalizations t) async {
    try {
      await ref.read(roadmapProvider.notifier).generate();
    } on DioException catch (e) {
      if (!context.mounted) return;
      if (e.response?.statusCode == 429) {
        String message = t.t('dashboard.regen_limit_reached');
        final detail = e.response?.data;
        if (detail is Map) {
          final inner = detail['detail'];
          if (inner is Map && inner['error'] != null) {
            message = inner['error'].toString();
          }
        }
        AppSnackbar.error(context, message);
      }
    } catch (_) {}
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, AppLocalizations t, RoadmapState state) {
    if (state.generationStatus == 'generating') {
      return _buildGenerating(theme, cs, t);
    }
    if (state.generationStatus == 'error') {
      return _buildError(context, ref, theme, cs, t);
    }
    if (state.roadmap != null) {
      return _buildRoadmap(context, ref, theme, cs, t, state);
    }
    return _buildEmpty(context, ref, theme, cs, t);
  }

  Widget _buildGenerating(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/processing.svg', width: 220.w, height: 220.h),
            SizedBox(height: 24.h),
            Text(t.t('dashboard.generating_title'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(t.t('dashboard.generating_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            SizedBox(
              width: 180.w,
              child: LinearProgressIndicator(borderRadius: BorderRadius.circular(4.r)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64.sp, color: cs.error),
            SizedBox(height: 16.h),
            Text(t.t('dashboard.error_title'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Text(t.t('dashboard.error_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: () => _regenerate(context, ref, t),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.t('dashboard.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 64.sp, color: cs.primary),
            SizedBox(height: 16.h),
            Text(t.t('dashboard.empty_title'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Text(t.t('dashboard.empty_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: () => _regenerate(context, ref, t),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(t.t('dashboard.generate')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmap(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, AppLocalizations t, RoadmapState state) {
    final roadmap = state.roadmap!;
    final phases = (roadmap['phases'] as List?) ?? [];
    final targetJobs = (roadmap['target_jobs'] as List?)?.cast<String>() ?? [];
    final notifier = ref.read(roadmapProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.loadRoadmap(),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          if (targetJobs.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Wrap(
                spacing: 8.w,
                children: targetJobs
                    .map((job) => Chip(
                          label: Text(job, style: TextStyle(fontSize: 12.sp)),
                          avatar: Icon(Icons.work_outline, size: 16.sp),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          ...List.generate(phases.length, (i) {
            final phase = phases[i] as Map<String, dynamic>;
            return PhaseCard(
              index: i,
              phase: phase,
              isLast: i == phases.length - 1,
              onTogglePhaseComplete: (phaseNumber) async {
                try {
                  await notifier.togglePhaseComplete(phaseNumber);
                } catch (_) {
                  if (context.mounted) {
                    AppSnackbar.error(context, t.t('dashboard.update_error'));
                  }
                }
              },
              onToggleActionComplete: (phaseNumber, actionIndex) async {
                try {
                  await notifier.toggleActionComplete(phaseNumber, actionIndex);
                } catch (_) {
                  if (context.mounted) {
                    AppSnackbar.error(context, t.t('dashboard.update_error'));
                  }
                }
              },
            );
          }),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
