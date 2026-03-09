import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    final userAsync = ref.watch(userProvider);
    final roadmapState = ref.watch(roadmapProvider);
    final appsAsync = ref.watch(applicationsProvider);
    final regenAsync = ref.watch(regenerationStatusProvider);

    final firstName = userAsync.whenOrNull(data: (u) => u['first_name'] as String?) ?? '';
    final applications = appsAsync.whenOrNull(data: (a) => a) ?? [];
    final regenStatus = regenAsync.whenOrNull(data: (s) => s);
    final roadmap = roadmapState.roadmap;

    if (roadmapState.isLoading) return const Center(child: CircularProgressIndicator());

    // Calculs de progression
    final phases = (roadmap?['phases'] as List?) ?? [];
    final allSkills = phases.expand((p) => (p['skills'] as List?) ?? []).toList();
    final allActions = phases.expand((p) => (p['actions'] as List?) ?? []).toList();
    final completedActions = allActions.where((a) => a['completed'] == true).length;
    final completedSkills = allSkills.where((s) => s['completed'] == true).length;
    final totalActions = allActions.length;
    final totalSkills = allSkills.length;
    final actionPercent = totalActions > 0 ? (completedActions / totalActions * 100).round() : 0;
    final totalWeeks = roadmap?['summary']?['total_duration_weeks'] ?? 0;

    final activeApps = applications.where(
      (a) => !['rejected', 'withdrawn', 'accepted'].contains(a['status']),
    ).length;
    final interviews = applications.where(
      (a) => ['phone_screen', 'technical', 'final_interview'].contains(a['status']),
    ).length;
    final regenRemaining = (regenStatus?['remaining'] ?? 0) as int;

    // Phase en cours
    final currentPhase = phases.cast<Map<String, dynamic>>().firstWhere(
      (p) => p['completed'] != true,
      orElse: () => phases.isNotEmpty ? phases.first as Map<String, dynamic> : <String, dynamic>{},
    );

    final keyMessage = roadmap?['summary']?['key_message'] as String? ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(roadmapProvider.notifier).loadRoadmap();
        ref.read(applicationsProvider.notifier).refresh();
        ref.read(regenerationStatusProvider.notifier).refresh();
        ref.read(userProvider.notifier).refresh();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        children: [
          // Salutation
          Text(t.t('home.greeting'),
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          SizedBox(height: 2.h),
          Text('$firstName 👋',
              style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
          SizedBox(height: 20.h),

          // Carte progression
          if (roadmap != null) ...[
            _ProgressCard(
              actionPercent: actionPercent,
              completedActions: completedActions,
              totalActions: totalActions,
              completedSkills: completedSkills,
              totalSkills: totalSkills,
              totalWeeks: totalWeeks,
              cs: cs,
              t: t,
            ),
            SizedBox(height: 20.h),
          ],

          // Stats rapides
          Row(
            children: [
              _StatCard(value: '$activeApps', label: t.t('home.applications_stat'), icon: '📋', color: const Color(0xFF2563EB)),
              SizedBox(width: 10.w),
              _StatCard(value: '$interviews', label: t.t('home.interviews_stat'), icon: '💬', color: const Color(0xFF7C3AED)),
              SizedBox(width: 10.w),
              _StatCard(value: '$regenRemaining', label: t.t('home.regenerations_stat'), icon: '✨', color: const Color(0xFFF59E0B)),
            ],
          ),
          SizedBox(height: 24.h),

          // Phase en cours
          if (currentPhase.isNotEmpty) ...[
            _SectionHeader(
              title: t.t('home.current_phase'),
              action: t.t('home.view_all'),
              onAction: () => context.go('/roadmap'),
            ),
            SizedBox(height: 8.h),
            _CurrentPhaseCard(phase: currentPhase, cs: cs, t: t, onTap: () => context.go('/roadmap')),
            SizedBox(height: 24.h),
          ],

          // Candidatures récentes
          if (applications.isNotEmpty) ...[
            _SectionHeader(
              title: t.t('home.recent_applications'),
              action: t.t('home.view_all'),
              onAction: () => context.go('/applications'),
            ),
            SizedBox(height: 8.h),
            ...applications.take(3).map((app) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: _ApplicationTile(app: app, cs: cs, t: t, onTap: () => context.go('/applications')),
            )),
            SizedBox(height: 16.h),
          ],

          // Conseil du jour
          if (keyMessage.isNotEmpty)
            _TipCard(message: keyMessage, t: t),

          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

// ─── Sous-widgets ────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int actionPercent, completedActions, totalActions, completedSkills, totalSkills, totalWeeks;
  final ColorScheme cs;
  final AppLocalizations t;

  const _ProgressCard({
    required this.actionPercent, required this.completedActions, required this.totalActions,
    required this.completedSkills, required this.totalSkills, required this.totalWeeks,
    required this.cs, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.t('home.progress_title'),
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700,
                  color: Colors.white70, letterSpacing: 1)),
          SizedBox(height: 14.h),
          Row(
            children: [
              _ProgressRing(percent: actionPercent, size: 64.w),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$completedActions/$totalActions ${t.t('home.actions_label')}',
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(height: 4.h),
                    Text('$completedSkills/$totalSkills ${t.t('home.skills_acquired')} · ~$totalWeeks ${t.t('home.weeks_label')}',
                        style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int percent;
  final double size;
  const _ProgressRing({required this.percent, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 5.w,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text('$percent%',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label, icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: TextStyle(fontSize: 18.sp)),
            SizedBox(height: 6.h),
            Text(value, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: color)),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.primary)),
          ),
      ],
    );
  }
}

class _CurrentPhaseCard extends StatelessWidget {
  final Map<String, dynamic> phase;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;
  const _CurrentPhaseCard({required this.phase, required this.cs, required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    final actions = (phase['actions'] as List?) ?? [];
    final skills = (phase['skills'] as List?) ?? [];
    final done = actions.where((a) => a['completed'] == true).length;
    final total = actions.length;
    final progress = total > 0 ? done / total : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t.t('home.phase_label')} ${phase['phase_number'] ?? ''}',
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700,
                              color: cs.primary, letterSpacing: 1)),
                      SizedBox(height: 4.h),
                      Text(phase['title'] as String? ?? '',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text('$done/$total',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.primary)),
              ],
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6.h,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: skills.map<Widget>((s) {
                final completed = s['completed'] == true;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: completed ? const Color(0xFFD1FAE5) : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    s['name'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: completed ? const Color(0xFF059669) : cs.primary,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;
  const _ApplicationTile({required this.app, required this.cs, required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    final company = app['company_name'] as String? ?? '';
    final jobTitle = app['job_title'] as String? ?? '';
    final status = app['status'] as String? ?? 'applied';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(company.isNotEmpty ? company[0] : '?',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: cs.primary)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobTitle,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(company, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            StatusBadge(status: status, t: t),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final AppLocalizations t;
  const StatusBadge({super.key, required this.status, required this.t});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status, t);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: config.$3,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5.w, height: 5.w, decoration: BoxDecoration(shape: BoxShape.circle, color: config.$2)),
          SizedBox(width: 5.w),
          Text(config.$1, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: config.$2)),
        ],
      ),
    );
  }
}

(String, Color, Color) _statusConfig(String status, AppLocalizations t) {
  return switch (status) {
    'applied' => (t.t('applications_screen.status_applied'), const Color(0xFF64748B), const Color(0xFFF1F5F9)),
    'phone_screen' => (t.t('applications_screen.status_phone_screen'), const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
    'technical' => (t.t('applications_screen.status_technical'), const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
    'final_interview' => (t.t('applications_screen.status_final_interview'), const Color(0xFFD97706), const Color(0xFFFEF3C7)),
    'offer' => (t.t('applications_screen.status_offer'), const Color(0xFF059669), const Color(0xFFD1FAE5)),
    'accepted' => (t.t('applications_screen.status_accepted'), const Color(0xFF047857), const Color(0xFFA7F3D0)),
    'rejected' => (t.t('applications_screen.status_rejected'), const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
    'withdrawn' => (t.t('applications_screen.status_withdrawn'), const Color(0xFF94A3B8), const Color(0xFFF9FAFB)),
    _ => (status, const Color(0xFF64748B), const Color(0xFFF1F5F9)),
  };
}

class _TipCard extends StatelessWidget {
  final String message;
  final AppLocalizations t;
  const _TipCard({required this.message, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡', style: TextStyle(fontSize: 20.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.t('home.tip_title'),
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text(message,
                    style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
