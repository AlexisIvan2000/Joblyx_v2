import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/dashboard_widgets.dart';

/// Carte affichant le résumé d'une candidature dans la liste.
class ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final VoidCallback? onTap;

  const ApplicationCard({
    super.key,
    required this.app,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final company = app['company_name'] as String? ?? '';
    final jobTitle = app['job_title'] as String? ?? '';
    final status = app['status'] as String? ?? 'applied';
    final appliedAt = app['applied_at'] as String? ?? '';

    // Calcul du nombre de jours depuis la candidature
    String daysAgo = '';
    if (appliedAt.isNotEmpty) {
      final date = DateTime.tryParse(appliedAt);
      if (date != null) {
        final diff = DateTime.now().difference(date).inDays;
        daysAgo = '$diff${t.t('applications_screen.days_ago')}';
      }
    }

    final statusColors = statusConfig(status, t);

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Avatar avec initiale de l'entreprise
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: statusColors.$3,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    company.isNotEmpty ? company[0] : '?',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: statusColors.$2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Titre du poste et nom de l'entreprise
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobTitle,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      company,
                      style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Badge de statut et date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: status, t: t),
                  if (daysAgo.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      daysAgo,
                      style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Configuration des couleurs par statut : (label, couleur, fond).
(String, Color, Color) statusConfig(String status, AppLocalizations t) {
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
