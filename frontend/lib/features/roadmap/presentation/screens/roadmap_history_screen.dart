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

  /// Bottom sheet avec les options : voir détails / restaurer / supprimer.
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
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              leading: Icon(Icons.visibility_outlined, color: cs.primary),
              title: Text(t.t('dashboard.history_view')),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/roadmap/history/$id');
              },
            ),
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
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: Text(t.t('dashboard.history_delete'),
                  style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDelete(id);
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
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('dashboard.history_restore_error'));
      }
    }
  }

  /// Supprimer une roadmap archivée.
  Future<void> _confirmDelete(String roadmapId) async {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('dashboard.history_delete')),
        content: Text(t.t('dashboard.history_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.t('application_detail.delete'),
                style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(roadmapServiceProvider).deleteRoadmap(roadmapId);
      if (mounted) {
        AppSnackbar.success(context, t.t('dashboard.history_deleted'));
        _loadHistory();
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('dashboard.history_delete_error'));
      }
    }
  }

  /// Supprimer toutes les roadmaps archivées.
  Future<void> _confirmDeleteAll() async {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('dashboard.history_delete_all')),
        content: Text(t.t('dashboard.history_delete_all_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.t('application_detail.delete'),
                style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await ref.read(roadmapServiceProvider).deleteAllArchived();
      if (mounted) {
        AppSnackbar.success(context,
            t.t('dashboard.history_deleted_all').replaceAll('{count}', '$count'));
        _loadHistory();
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('dashboard.history_delete_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('dashboard.history')),
        actions: [
          if (_history != null && _history!.isNotEmpty)
            IconButton(
              onPressed: _confirmDeleteAll,
              icon: Icon(Icons.delete_sweep_rounded, size: 22.sp),
              tooltip: t.t('dashboard.history_delete_all'),
            ),
        ],
      ),
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
    final createdAt = item['created_at'] as String? ?? '';
    final phases = (item['phases'] as List?) ?? [];
    final phaseCount = phases.length;
    final completedCount = phases
        .where((p) => (p as Map<String, dynamic>)['completed'] == true)
        .length;
    final progress = phaseCount > 0 ? completedCount / phaseCount : 0.0;

    // Titres des phases (max 3)
    final phaseTitles = phases
        .take(3)
        .map((p) => (p as Map<String, dynamic>)['title'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

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
              // En-tête : date + chevron
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

              // Titres des phases
              if (phaseTitles.isNotEmpty) ...[
                ...phaseTitles.asMap().entries.map((e) => Padding(
                      padding: EdgeInsets.only(bottom: 3.h),
                      child: Row(
                        children: [
                          Container(
                            width: 18.w,
                            height: 18.w,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (phaseCount > 3)
                  Padding(
                    padding: EdgeInsets.only(left: 26.w),
                    child: Text(
                      '+${phaseCount - 3} ${t.t('dashboard.history_more_phases')}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                SizedBox(height: 10.h),
              ],

              // Barre de progression
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6.h,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: completedCount == phaseCount && phaseCount > 0
                            ? const Color(0xFF5DCAA5)
                            : cs.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '$completedCount/$phaseCount',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
