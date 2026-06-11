import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/core/widgets/staggered_list.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/widgets/dashboard_widgets.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';
import 'package:frontend/core/tutorial/tutorial_keys.dart';
import 'package:frontend/core/tutorial/feature_tour.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _tourScheduled = false;

  // Déclenche le tour guidé une seule fois, après le rendu du contenu réel
  void _scheduleTourIfNeeded() {
    if (_tourScheduled) return;
    _tourScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await hasSeenTour()) return;
      if (!mounted) return;
      showFeatureTour(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final keys = TutorialKeys.instance;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    final userAsync = ref.watch(userProvider);
    final roadmapState = ref.watch(roadmapProvider);
    final appsAsync = ref.watch(applicationsProvider);
    final regenAsync = ref.watch(regenerationStatusProvider);

    final user = userAsync.whenOrNull(data: (u) => u);
    final firstName = user?['first_name'] as String? ?? '';
    final lastName = user?['last_name'] as String? ?? '';
    final avatarUrl = user?['avatar_url'] as String?;
    final applications = appsAsync.whenOrNull(data: (a) => a) ?? [];
    final regenStatus = regenAsync.whenOrNull(data: (s) => s);
    final roadmap = roadmapState.roadmap;

    if (roadmapState.isLoading) return const DashboardSkeleton();

    _scheduleTourIfNeeded();

    // Calculs de progression
    final phases = (roadmap?['phases'] as List?) ?? [];
    final allSkills =
        phases.expand((p) => (p['skills'] as List?) ?? []).toList();
    final allActions =
        phases.expand((p) => (p['actions'] as List?) ?? []).toList();
    final completedActions =
        allActions.where((a) => a['completed'] == true).length;
    final completedSkills =
        allSkills.where((s) => s['completed'] == true).length;
    final totalActions = allActions.length;
    final totalSkills = allSkills.length;
    final actionPercent =
        totalActions > 0 ? (completedActions / totalActions * 100).round() : 0;
    final totalWeeks = roadmap?['summary']?['total_duration_weeks'] ?? 0;

    final activeApps = applications
        .where(
            (a) => !['rejected', 'ghosted', 'withdrawn', 'accepted'].contains(a['status']))
        .length;
    final interviews = applications
        .where((a) =>
            ['phone_screen', 'technical', 'final_interview']
                .contains(a['status']))
        .length;
    final regenRemaining = (regenStatus?['remaining'] ?? 0) as int;

    final currentPhase = phases.cast<Map<String, dynamic>>().firstWhere(
          (p) => p['completed'] != true,
          orElse: () => phases.isNotEmpty
              ? phases.first as Map<String, dynamic>
              : <String, dynamic>{},
        );

    final keyMessage =
        roadmap?['summary']?['key_message'] as String? ?? '';

    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    // Salutation selon l'heure locale
    final hour = DateTime.now().hour;
    final greetingKey = hour < 12
        ? 'home.greeting_morning'
        : hour < 18
            ? 'home.greeting_afternoon'
            : 'home.greeting_evening';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20.w,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 20.r,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                backgroundImage:
                    avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(initials,
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: cs.primary))
                    : null,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t(greetingKey),
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  Text(firstName,
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.read(roadmapProvider.notifier).loadRoadmap(),
          ref.read(applicationsProvider.notifier).refresh(),
          ref.read(regenerationStatusProvider.notifier).refresh(),
          ref.read(userProvider.notifier).refresh(),
        ]),
        child: ListView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          children: [
            StaggeredList(
              children: [
                Padding(
                  key: keys.roadmapCard,
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: roadmap != null
                      ? ProgressCard(
                          actionPercent: actionPercent,
                          completedActions: completedActions,
                          totalActions: totalActions,
                          completedSkills: completedSkills,
                          totalSkills: totalSkills,
                          totalWeeks: totalWeeks,
                          cs: cs,
                          t: t,
                        )
                      : EmptyRoadmapCard(
                          cs: cs,
                          t: t,
                          onGenerateAI: () => context.push('/roadmap/generate-ai'),
                          onCreateManual: () => context.push('/roadmap/create'),
                        ),
                ),
                Padding(
                  key: keys.statsCard,
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Row(
                    children: [
                      StatCard(
                          value: '$activeApps',
                          label: t.t('home.applications_stat'),
                          icon: '\u{1F4CB}',
                          color: const Color(0xFF2563EB)),
                      SizedBox(width: 10.w),
                      StatCard(
                          value: '$interviews',
                          label: t.t('home.interviews_stat'),
                          icon: '\u{1F4AC}',
                          color: const Color(0xFF7C3AED)),
                      SizedBox(width: 10.w),
                      StatCard(
                          value: '$regenRemaining',
                          label: t.t('home.regenerations_stat'),
                          icon: '\u2728',
                          color: const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
                if (currentPhase.isNotEmpty) ...[
                  SectionHeader(
                    title: t.t('home.current_phase'),
                    action: t.t('home.view_all'),
                    onAction: () => context.go('/roadmap'),
                  ),
                  Padding(
                    key: keys.currentPhase,
                    padding: EdgeInsets.only(top: 8.h, bottom: 24.h),
                    child: CurrentPhaseCard(
                        phase: currentPhase,
                        cs: cs,
                        t: t,
                        onTap: () => context.go('/roadmap')),
                  ),
                ],
                SectionHeader(
                  title: t.t('home.recent_applications'),
                  action: applications.isNotEmpty ? t.t('home.view_all') : null,
                  onAction: applications.isNotEmpty
                      ? () => context.go('/applications')
                      : null,
                ),
                Padding(
                  padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
                  child: applications.isNotEmpty
                      ? Column(
                          children: applications
                              .take(3)
                              .map((app) => Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: ApplicationTile(
                                        app: app,
                                        cs: cs,
                                        t: t,
                                        onTap: () => context.go('/applications')),
                                  ))
                              .toList(),
                        )
                      : EmptyApplicationsCard(
                          cs: cs,
                          t: t,
                          onTap: () => context.go('/applications'),
                        ),
                ),
                if (keyMessage.isNotEmpty)
                  TipCard(message: keyMessage, t: t),
                SizedBox(height: 12.h),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
