import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/roadmap/presentation/screens/dashboard_screen.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  String _filter = 'all';

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> apps) {
    if (_filter == 'all') return apps;
    if (_filter == 'active') {
      return apps.where((a) =>
          ['applied', 'phone_screen', 'technical', 'final_interview'].contains(a['status'])).toList();
    }
    if (_filter == 'interviews') {
      return apps.where((a) =>
          ['phone_screen', 'technical', 'final_interview'].contains(a['status'])).toList();
    }
    // closed
    return apps.where((a) =>
        ['rejected', 'withdrawn', 'accepted'].contains(a['status'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final appsAsync = ref.watch(applicationsProvider);

    return Scaffold(
      body: SafeArea(
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48.sp, color: cs.error),
                SizedBox(height: 12.h),
                Text(t.t('applications_screen.empty')),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: () => ref.read(applicationsProvider.notifier).refresh(),
                  child: Text(t.t('settings.retry')),
                ),
              ],
            ),
          ),
          data: (applications) {
            final filtered = _applyFilter(applications);
            return RefreshIndicator(
              onRefresh: () => ref.read(applicationsProvider.notifier).refresh(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                children: [
                  // Titre + bouton +
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.t('applications_screen.title'),
                          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add, color: Colors.white, size: 20.sp),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // TODO: ouvrir le formulaire d'ajout
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Filtres
                  SizedBox(
                    height: 36.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(label: t.t('applications_screen.filter_all'), key_: 'all', current: _filter, onTap: (k) => setState(() => _filter = k)),
                        SizedBox(width: 6.w),
                        _FilterChip(label: t.t('applications_screen.filter_active'), key_: 'active', current: _filter, onTap: (k) => setState(() => _filter = k)),
                        SizedBox(width: 6.w),
                        _FilterChip(label: t.t('applications_screen.filter_interviews'), key_: 'interviews', current: _filter, onTap: (k) => setState(() => _filter = k)),
                        SizedBox(width: 6.w),
                        _FilterChip(label: t.t('applications_screen.filter_closed'), key_: 'closed', current: _filter, onTap: (k) => setState(() => _filter = k)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Liste
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60.h),
                        child: Text(t.t('applications_screen.empty'),
                            style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
                      ),
                    )
                  else
                    ...filtered.map((app) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _AppCard(app: app, cs: cs, t: t),
                    )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label, key_, current;
  final void Function(String) onTap;
  const _FilterChip({required this.label, required this.key_, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = key_ == current;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(key_),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isActive ? cs.onSurface : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600,
                color: isActive ? cs.surface : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final ColorScheme cs;
  final AppLocalizations t;
  const _AppCard({required this.app, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    final company = app['company_name'] as String? ?? '';
    final jobTitle = app['job_title'] as String? ?? '';
    final status = app['status'] as String? ?? 'applied';
    final appliedAt = app['applied_at'] as String? ?? '';

    String daysAgo = '';
    if (appliedAt.isNotEmpty) {
      final date = DateTime.tryParse(appliedAt);
      if (date != null) {
        final diff = DateTime.now().difference(date).inDays;
        daysAgo = '$diff${t.t('applications_screen.days_ago')}';
      }
    }

    final statusColors = _statusConfig(status, t);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: statusColors.$3,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(company.isNotEmpty ? company[0] : '?',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: statusColors.$2)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jobTitle,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Text(company, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: status, t: t),
              if (daysAgo.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(daysAgo, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
              ],
            ],
          ),
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
