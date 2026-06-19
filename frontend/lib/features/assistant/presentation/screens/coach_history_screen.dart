import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';

/// Écran historique complet des analyses coach.
class CoachHistoryScreen extends ConsumerWidget {
  const CoachHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(coachHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('assistant.history_title')),
        actions: [
          historyAsync.when(
            data: (sessions) => sessions.isNotEmpty
                ? IconButton(
                    onPressed: () => _confirmDeleteAll(context, ref, t, cs),
                    icon: Icon(Icons.delete_sweep_rounded, size: 22.sp),
                    tooltip: t.t('assistant.delete_all'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            t.t('assistant.analyze_error'),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48.sp,
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    t.t('assistant.no_history'),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(coachHistoryProvider.notifier).refresh(),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.w,
                16.w,
                16.w + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final s = sessions[index];
                return _HistoryCard(
                  session: s,
                  cs: cs,
                  onTap: () => context.push('/assistant/coach/${s['id']}'),
                  onDelete: () =>
                      _confirmDelete(context, ref, t, cs, s['id'] as String),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    ColorScheme cs,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('assistant.delete_session')),
        content: Text(t.t('assistant.delete_session_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.t('application_detail.delete'),
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(coachHistoryProvider.notifier).deleteSession(id);
      if (context.mounted) {
        AppSnackbar.success(context, t.t('assistant.session_deleted'));
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, t.t('assistant.delete_error'));
      }
    }
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    ColorScheme cs,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('assistant.delete_all')),
        content: Text(t.t('assistant.delete_all_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.t('application_detail.delete'),
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final count = await ref.read(coachHistoryProvider.notifier).deleteAll();
      if (context.mounted) {
        AppSnackbar.success(
          context,
          t.t('assistant.all_deleted').replaceAll('{count}', '$count'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, t.t('assistant.delete_error'));
      }
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.session,
    required this.cs,
    required this.onTap,
    required this.onDelete,
  });

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
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    final scoreColor = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
        ? const Color(0xFFFFB347)
        : const Color(0xFFE57373);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 4.w, 12.h),
          child: Row(
            children: [
              // Score circulaire
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Titre + entreprise
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (jobTitle.isNotEmpty)
                      Text(
                        jobTitle,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (company.isNotEmpty)
                      Text(
                        company,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Bouton supprimer
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18.sp,
                  color: cs.outlineVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
