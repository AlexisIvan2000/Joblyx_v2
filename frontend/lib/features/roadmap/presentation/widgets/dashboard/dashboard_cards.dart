
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

//  Carte de progression globale 

class ProgressCard extends StatelessWidget {
  final int actionPercent, completedActions, totalActions;
  final int completedSkills, totalSkills, totalWeeks;
  final ColorScheme cs;
  final AppLocalizations t;

  const ProgressCard({
    super.key,
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.t('home.progress_title'),
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
        SizedBox(height: 14.h),
        Row(children: [
          ProgressRing(percent: actionPercent, size: 64.w),
          SizedBox(width: 20.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$completedActions/$totalActions ${t.t('home.actions_label')}',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(height: 4.h),
            Text('$completedSkills/$totalSkills ${t.t('home.skills_acquired')} · ~$totalWeeks ${t.t('home.weeks_label')}',
                style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
          ])),
        ]),
      ]),
    );
  }
}

// Anneau de progression animé 

class ProgressRing extends StatefulWidget {
  final int percent;
  final double size;
  const ProgressRing({super.key, required this.percent, this.size = 48});

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = Tween<double>(begin: 0, end: widget.percent / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(begin: _animation.value, end: widget.percent / 100)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final p = (_animation.value * 100).round();
        return SizedBox(
          width: widget.size, height: widget.size,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: widget.size, height: widget.size, child: CircularProgressIndicator(
              value: _animation.value, strokeWidth: 5.w,
              backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeCap: StrokeCap.round,
            )),
            Text('$p%', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        );
      },
    );
  }
}

// Carte de statistique 

class StatCard extends StatelessWidget {
  final String value, label, icon;
  final Color color;
  const StatCard({super.key, required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: TextStyle(fontSize: 18.sp)),
          SizedBox(height: 6.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim), child: child,
            )),
            child: Text(value, key: ValueKey(value),
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: color)),
          ),
          SizedBox(height: 2.h),
          Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

//  Carte de la phase en cours 

class CurrentPhaseCard extends StatelessWidget {
  final Map<String, dynamic> phase;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;
  const CurrentPhaseCard({super.key, required this.phase, required this.cs, required this.t, this.onTap});

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
          color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.t('home.phase_label')} ${phase['phase_number'] ?? ''}',
                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 1)),
              SizedBox(height: 4.h),
              Text(phase['title'] as String? ?? '',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                  overflow: TextOverflow.ellipsis),
            ])),
            SizedBox(width: 8.w),
            Text('$done/$total', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.primary)),
          ]),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(3.r),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value, minHeight: 6.h,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3), valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(spacing: 6.w, runSpacing: 6.h, children: skills.map<Widget>((s) {
            final completed = s['completed'] == true;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: completed ? const Color(0xFFD1FAE5) : const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(s['name'] as String? ?? '', style: TextStyle(
                fontSize: 11.sp, fontWeight: FontWeight.w600,
                color: completed ? const Color(0xFF059669) : cs.primary,
                decoration: completed ? TextDecoration.lineThrough : null,
              )),
            );
          }).toList()),
        ]),
      ),
    );
  }
}

//  Carte conseil du jour 

class TipCard extends StatelessWidget {
  final String message;
  final AppLocalizations t;
  const TipCard({super.key, required this.message, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('\u{1F4A1}', style: TextStyle(fontSize: 20.sp)),
        SizedBox(width: 10.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.t('home.tip_title'),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          SizedBox(height: 4.h),
          Text(message, style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B), height: 1.5)),
        ])),
      ]),
    );
  }
}
