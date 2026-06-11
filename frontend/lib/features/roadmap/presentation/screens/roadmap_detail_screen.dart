import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase/phase_card.dart';

/// Écran de détail en lecture seule pour un roadmap archivé.
class RoadmapDetailScreen extends ConsumerStatefulWidget {
  final String roadmapId;

  const RoadmapDetailScreen({super.key, required this.roadmapId});

  @override
  ConsumerState<RoadmapDetailScreen> createState() =>
      _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends ConsumerState<RoadmapDetailScreen> {
  Map<String, dynamic>? _roadmap;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(roadmapServiceProvider);
      final data = await svc.getRoadmapById(widget.roadmapId);
      if (mounted) setState(() => _roadmap = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Restaurer ce roadmap archivé.
  Future<void> _restore() async {
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
      await ref.read(roadmapProvider.notifier).restoreRoadmap(widget.roadmapId);
      if (mounted) {
        AppSnackbar.success(context, t.t('dashboard.history_restored'));
        // Retourner deux fois (détail → historique → roadmap)
        Navigator.of(context)
          ..pop()
          ..pop();
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
      appBar: AppBar(
        title: Text(t.t('dashboard.history')),
        actions: [
          // Bouton restaurer dans l'AppBar
          if (_roadmap != null)
            IconButton(
              onPressed: _restore,
              icon: Icon(Icons.restore_rounded, size: 22.sp),
              tooltip: t.t('dashboard.history_restore'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48.sp,
                      color: cs.error,
                    ),
                    SizedBox(height: 12.h),
                    FilledButton(
                      onPressed: _load,
                      child: Text(t.t('settings.retry')),
                    ),
                  ],
                ),
              )
            : _buildContent(cs, t),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, AppLocalizations t) {
    final roadmap = _roadmap!;
    final phases = (roadmap['phases'] as List?) ?? [];
    final createdAt = roadmap['created_at'] as String? ?? '';

    // Formater la date
    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        // Date de création
        if (dateStr.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14.sp,
                  color: cs.onSurfaceVariant,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${t.t('dashboard.history_created')} $dateStr',
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

        // Phases en lecture seule (sans callbacks de modification)
        ...List.generate(phases.length, (i) {
          final phase = phases[i] as Map<String, dynamic>;
          return PhaseCard(
            index: i,
            phase: phase,
            isLast: i == phases.length - 1,
          );
        }),
        SizedBox(height: 20.h),
      ],
    );
  }
}
