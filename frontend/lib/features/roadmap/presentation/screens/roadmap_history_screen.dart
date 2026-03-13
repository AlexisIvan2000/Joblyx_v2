import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';

/// Écran affichant l'historique des roadmaps générés.
class RoadmapHistoryScreen extends ConsumerStatefulWidget {
  const RoadmapHistoryScreen({super.key});

  @override
  ConsumerState<RoadmapHistoryScreen> createState() =>
      _RoadmapHistoryScreenState();
}

class _RoadmapHistoryScreenState extends ConsumerState<RoadmapHistoryScreen> {
  List<dynamic>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(roadmapServiceProvider);
      final data = await svc.getHistory();
      if (mounted) setState(() => _history = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bottom sheet avec les deux options : voir détails / restaurer.
  void _showOptions(Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final id = item['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            // Indicateur de drag
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 8.h),
            // Voir les détails
            ListTile(
              leading: Icon(Icons.visibility_outlined, color: cs.primary),
              title: Text(t.t('dashboard.history_view')),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/roadmap/history/$id');
              },
            ),
            // Restaurer ce roadmap
            ListTile(
              leading: Icon(Icons.restore_rounded, color: cs.tertiary),
              title: Text(t.t('dashboard.history_restore')),
              subtitle: Text(
                t.t('dashboard.history_restore_desc'),
                style: TextStyle(fontSize: 11.sp),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _confirmRestore(id);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  /// Dialog de confirmation avant restauration.
  Future<void> _confirmRestore(String roadmapId) async {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('dashboard.history_restore')),
        content: Text(t.t('dashboard.history_restore_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.t('dashboard.history_restore_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(roadmapProvider.notifier).restoreRoadmap(roadmapId);
      if (mounted) {
        AppSnackbar.success(context, t.t('dashboard.history_restored'));
        // Retourner à la page roadmap
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('dashboard.history_restore_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('dashboard.history'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48.sp, color: cs.error),
                      SizedBox(height: 12.h),
                      FilledButton(
                        onPressed: _loadHistory,
                        child: Text(t.t('settings.retry')),
                      ),
                    ],
                  ),
                )
              : _history == null || _history!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 48.sp, color: cs.onSurfaceVariant),
                          SizedBox(height: 12.h),
                          Text(
                            t.t('dashboard.history_empty'),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _history!.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final item =
                              _history![index] as Map<String, dynamic>;
                          return _HistoryCard(
                            item: item,
                            cs: cs,
                            t: t,
                            onTap: () => _showOptions(item),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Carte affichant un roadmap dans l'historique.
class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.cs,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final targetJobs =
        (item['target_jobs'] as List?)?.cast<String>() ?? [];
    final createdAt = item['created_at'] as String? ?? '';

    // Formater la date
    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date de création
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14.sp, color: cs.onSurfaceVariant),
                  SizedBox(width: 6.w),
                  if (dateStr.isNotEmpty)
                    Text(
                      '${t.t('dashboard.history_created')} $dateStr',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 20.sp, color: cs.onSurfaceVariant),
                ],
              ),
              SizedBox(height: 10.h),

              // Postes ciblés
              if (targetJobs.isNotEmpty)
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: targetJobs
                      .map((job) => Chip(
                            label: Text(job, style: TextStyle(fontSize: 11.sp)),
                            avatar: Icon(Icons.work_outline, size: 14.sp),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
