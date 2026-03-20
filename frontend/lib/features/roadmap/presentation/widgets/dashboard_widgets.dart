import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

// ─── Progress Card ──────────────────────────────────────────────

class ProgressCard extends StatelessWidget {
  final int actionPercent, completedActions, totalActions;
  final int completedSkills, totalSkills, totalWeeks;
  final ColorScheme cs;
  final AppLocalizations t;

  const ProgressCard({
    super.key,
    required this.actionPercent,
    required this.completedActions,
    required this.totalActions,
    required this.completedSkills,
    required this.totalSkills,
    required this.totalWeeks,
    required this.cs,
    required this.t,
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
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  letterSpacing: 1)),
          SizedBox(height: 14.h),
          Row(
            children: [
              ProgressRing(percent: actionPercent, size: 64.w),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$completedActions/$totalActions ${t.t('home.actions_label')}',
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    SizedBox(height: 4.h),
                    Text(
                        '$completedSkills/$totalSkills ${t.t('home.skills_acquired')} · ~$totalWeeks ${t.t('home.weeks_label')}',
                        style:
                            TextStyle(fontSize: 12.sp, color: Colors.white70)),
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

// ─── Progress Ring ──────────────────────────────────────────────

class ProgressRing extends StatefulWidget {
  final int percent;
  final double size;
  const ProgressRing({super.key, required this.percent, this.size = 48});

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.percent / 100).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percent / 100,
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentPercent = (_animation.value * 100).round();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _animation.value,
                  strokeWidth: 5.w,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text('$currentPercent%',
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat Card ──────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String value, label, icon;
  final Color color;
  const StatCard(
      {super.key,
      required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14.r),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: TextStyle(fontSize: 18.sp)),
            SizedBox(height: 6.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(value,
                  key: ValueKey(value),
                  style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
            SizedBox(height: 2.h),
            Text(label,
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.primary)),
          ),
      ],
    );
  }
}

// ─── Current Phase Card ─────────────────────────────────────────

class CurrentPhaseCard extends StatelessWidget {
  final Map<String, dynamic> phase;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;

  const CurrentPhaseCard(
      {super.key,
      required this.phase,
      required this.cs,
      required this.t,
      this.onTap});

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
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
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
                      Text(
                          '${t.t('home.phase_label')} ${phase['phase_number'] ?? ''}',
                          style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                              letterSpacing: 1)),
                      SizedBox(height: 4.h),
                      Text(phase['title'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text('$done/$total',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ],
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6.h,
                  backgroundColor:
                      cs.outlineVariant.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: skills.map<Widget>((s) {
                final completed = s['completed'] == true;
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    s['name'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: completed
                          ? const Color(0xFF059669)
                          : cs.primary,
                      decoration:
                          completed ? TextDecoration.lineThrough : null,
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

// ─── Application Tile ───────────────────────────────────────────

class ApplicationTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;

  const ApplicationTile(
      {super.key,
      required this.app,
      required this.cs,
      required this.t,
      this.onTap});

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
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
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
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: cs.primary)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobTitle,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(company,
                      style: TextStyle(
                          fontSize: 11.sp, color: cs.onSurfaceVariant)),
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

// ─── Status Badge ───────────────────────────────────────────────

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
          Container(
              width: 5.w,
              height: 5.w,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: config.$2)),
          SizedBox(width: 5.w),
          Text(config.$1,
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: config.$2)),
        ],
      ),
    );
  }
}

(String, Color, Color) _statusConfig(String status, AppLocalizations t) {
  return switch (status) {
    'applied' => (t.t('applications_screen.status_applied'),
        const Color(0xFF64748B), const Color(0xFFF1F5F9)),
    'phone_screen' => (t.t('applications_screen.status_phone_screen'),
        const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
    'technical' => (t.t('applications_screen.status_technical'),
        const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
    'final_interview' => (t.t('applications_screen.status_final_interview'),
        const Color(0xFFD97706), const Color(0xFFFEF3C7)),
    'offer' => (t.t('applications_screen.status_offer'),
        const Color(0xFF059669), const Color(0xFFD1FAE5)),
    'accepted' => (t.t('applications_screen.status_accepted'),
        const Color(0xFF047857), const Color(0xFFA7F3D0)),
    'rejected' => (t.t('applications_screen.status_rejected'),
        const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
    'withdrawn' => (t.t('applications_screen.status_withdrawn'),
        const Color(0xFF94A3B8), const Color(0xFFF9FAFB)),
    _ => (status, const Color(0xFF64748B), const Color(0xFFF1F5F9)),
  };
}

// ─── Tip Card ───────────────────────────────────────────────────

class TipCard extends StatelessWidget {
  final String message;
  final AppLocalizations t;
  const TipCard({super.key, required this.message, required this.t});

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
          Text('\u{1F4A1}', style: TextStyle(fontSize: 20.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.t('home.tip_title'),
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A))),
                SizedBox(height: 4.h),
                Text(message,
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
