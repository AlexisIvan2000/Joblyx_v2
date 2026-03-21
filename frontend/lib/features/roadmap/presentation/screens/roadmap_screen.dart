import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase/phase_card.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase/phase_dialogs.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase/option_card.dart';

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
          // Bouton régénérer (appel direct API)
          if (state.hasRoadmap && state.generationStatus != 'generating')
            IconButton(
              onPressed: () => _regenerate(context, ref, t),
              icon: Icon(Icons.refresh_rounded, size: 22.sp),
              tooltip: t.t('dashboard.regenerate'),
            ),
          // Bouton historique
          IconButton(
            onPressed: () => context.push('/roadmap/history'),
            icon: Icon(Icons.history_rounded, size: 22.sp),
            tooltip: t.t('dashboard.history'),
          ),
        ],
      ),
      // FAB pour ajouter une phase custom
      floatingActionButton: (state.hasRoadmap && state.generationStatus != 'generating')
          ? FloatingActionButton(
              onPressed: () => _addPhase(context, ref, t),
              child: const Icon(Icons.add),
            )
          : null,
      body: state.isLoading
          ? const RoadmapSkeleton()
          : _buildBody(context, ref, theme, cs, t, state),
    );
  }

  /// Ouvrir le dialog d'ajout de phase custom.
  Future<void> _addPhase(BuildContext context, WidgetRef ref, AppLocalizations t) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddPhaseDialog(),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(roadmapProvider.notifier).addPhase(result);
      if (context.mounted) {
        AppSnackbar.success(context, t.t('dashboard.phase_added'));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, t.t('dashboard.add_phase_error'));
      }
    }
  }

  /// Régénérer la roadmap directement via l'API.
  Future<void> _regenerate(BuildContext context, WidgetRef ref, AppLocalizations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(t.t('dashboard.regenerate')),
        content: Text(t.t('dashboard.regenerate_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.t('dashboard.regenerate')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final notifier = ref.read(roadmapProvider.notifier);
      await for (final event in notifier.regenerate()) {
        final eventType = event['event'] as String;
        if (eventType == 'error') break;
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.error(context, t.t('dashboard.error_title'));
    }
  }

  /// Confirmer puis supprimer une phase.
  Future<void> _deletePhase(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String phaseId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(t.t('dashboard.delete_phase')),
        content: Text(t.t('dashboard.delete_phase_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.t('application_detail.delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(roadmapProvider.notifier).deletePhase(phaseId);
      if (context.mounted) {
        AppSnackbar.success(context, t.t('dashboard.phase_deleted'));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, t.t('dashboard.delete_phase_error'));
      }
    }
  }

  /// Ouvrir le dialog d'édition des notes.
  Future<void> _editNotes(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String phaseId,
    String currentNotes,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => EditNotesDialog(initialNotes: currentNotes),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(roadmapProvider.notifier).updatePhaseNotes(phaseId, result);
      if (context.mounted) {
        AppSnackbar.success(context, t.t('dashboard.notes_saved'));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, t.t('dashboard.notes_error'));
      }
    }
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
        padding: EdgeInsets.symmetric(horizontal: 24.w),
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
            SizedBox(height: 32.h),
            OptionCard(
              icon: Icons.auto_awesome_rounded,
              iconColor: cs.primary,
              title: t.t('dashboard.generate'),
              subtitle: t.t('dashboard.generate_ai_desc'),
              cs: cs,
              onTap: () => context.push('/roadmap/generate-ai'),
            ),
            SizedBox(height: 12.h),
            OptionCard(
              icon: Icons.edit_note_rounded,
              iconColor: cs.tertiary,
              title: t.t('dashboard.create_roadmap'),
              subtitle: t.t('dashboard.create_manual_desc'),
              cs: cs,
              onTap: () => context.push('/roadmap/create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmap(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, AppLocalizations t, RoadmapState state) {
    final roadmap = state.roadmap!;
    final phases = (roadmap['phases'] as List?) ?? [];
    final notifier = ref.read(roadmapProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.loadRoadmap(),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          ...List.generate(phases.length, (i) {
            final phase = phases[i] as Map<String, dynamic>;
            final phaseId = phase['id'] as String;
            return PhaseCard(
              index: i,
              phase: phase,
              isLast: i == phases.length - 1,
              onTogglePhaseComplete: (_) async {
                try {
                  await notifier.togglePhaseComplete(phaseId);
                } catch (_) {
                  if (context.mounted) {
                    AppSnackbar.error(context, t.t('dashboard.update_error'));
                  }
                }
              },
              onToggleActionComplete: (_, actionIndex) async {
                try {
                  await notifier.toggleActionComplete(phaseId, actionIndex);
                } catch (_) {
                  if (context.mounted) {
                    AppSnackbar.error(context, t.t('dashboard.update_error'));
                  }
                }
              },
              onDeletePhase: (_) => _deletePhase(context, ref, t, phaseId),
              onEditNotes: (_, currentNotes) =>
                  _editNotes(context, ref, t, phaseId, currentNotes),
            );
          }),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }
}

