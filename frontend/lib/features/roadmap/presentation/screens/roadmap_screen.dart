import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase_card.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _roadmapService = RoadmapService();

  bool _isLoading = true;
  String _generationStatus = 'idle';
  bool _hasRoadmap = false;
  Map<String, dynamic>? _roadmap;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _roadmapService.getStatus();
      if (!mounted) return;

      setState(() {
        _generationStatus = status['generation_status'] as String;
        _hasRoadmap = status['has_roadmap'] as bool;
        _isLoading = false;
      });

      if (_generationStatus == 'generating') {
        _startPolling();
      } else if (_hasRoadmap) {
        _loadRoadmap();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await _roadmapService.getStatus();
        if (!mounted) return;

        final newStatus = status['generation_status'] as String;
        final newHasRoadmap = status['has_roadmap'] as bool;

        if (newStatus != 'generating') {
          _pollTimer?.cancel();
          setState(() {
            _generationStatus = newStatus;
            _hasRoadmap = newHasRoadmap;
          });
          if (newHasRoadmap) _loadRoadmap();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadRoadmap() async {
    try {
      final roadmap = await _roadmapService.getRoadmap();
      if (!mounted) return;
      setState(() => _roadmap = roadmap);
    } catch (_) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      AppSnackbar.error(context, t.t('dashboard.roadmap_load_error'));
    }
  }

  Future<void> _regenerate() async {
    setState(() => _generationStatus = 'generating');
    try {
      await _roadmapService.generate();
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _generationStatus = 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('dashboard.title')),
        actions: [
          if (_hasRoadmap && _generationStatus != 'generating')
            IconButton(
              onPressed: _regenerate,
              icon: Icon(Icons.refresh_rounded, size: 22.sp),
              tooltip: t.t('dashboard.regenerate'),
            ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, size: 22.sp),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme, cs, t),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    if (_generationStatus == 'generating') {
      return _buildGenerating(theme, cs, t);
    }
    if (_generationStatus == 'error') {
      return _buildError(theme, cs, t);
    }
    if (_roadmap != null) {
      return _buildRoadmap(theme, cs, t);
    }
    return _buildEmpty(theme, cs, t);
  }

  // ─── Écran de génération en cours ────────────────────────────────
  Widget _buildGenerating(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/processing.svg',
              width: 220.w,
              height: 220.h,
            ),
            SizedBox(height: 24.h),
            Text(
              t.t('dashboard.generating_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              t.t('dashboard.generating_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: 180.w,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Écran d'erreur ──────────────────────────────────────────────
  Widget _buildError(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64.sp, color: cs.error),
            SizedBox(height: 16.h),
            Text(
              t.t('dashboard.error_title'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              t.t('dashboard.error_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.t('dashboard.retry')),
            ),
          ],
        ),
      ),
    );
  }

  // ─── État vide (pas de roadmap) ──────────────────────────────────
  Widget _buildEmpty(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 64.sp, color: cs.primary),
            SizedBox(height: 16.h),
            Text(
              t.t('dashboard.empty_title'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              t.t('dashboard.empty_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(t.t('dashboard.generate')),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Affichage du roadmap ────────────────────────────────────────
  Widget _buildRoadmap(ThemeData theme, ColorScheme cs, AppLocalizations t) {
    final phases = (_roadmap!['phases'] as List?) ?? [];
    final targetJobs = (_roadmap!['target_jobs'] as List?)?.cast<String>() ?? [];

    return RefreshIndicator(
      onRefresh: _loadRoadmap,
      child: ListView(
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
            );
          }),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
