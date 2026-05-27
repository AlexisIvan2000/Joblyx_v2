// Tuile candidature + badge statut pour le dashboard.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/constants/application_status.dart';

// Badge coloré du statut d'une candidature 

class StatusBadge extends StatelessWidget {
  final String status;
  final AppLocalizations t;
  const StatusBadge({super.key, required this.status, required this.t});

  @override
  Widget build(BuildContext context) {
    final cfg = ApplicationStatuses.fromKey(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: cfg.bgColor, borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cfg.borderColor),
      ),
      child: Text(t.t('applications_screen.status_$status'),
          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: cfg.textColor)),
    );
  }
}

//  Tuile d'une candidature dans la liste du dashboard

class ApplicationTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback? onTap;
  const ApplicationTile({super.key, required this.app, required this.cs, required this.t, this.onTap});

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
          color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 38.w, height: 38.w,
            decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(10.r)),
            child: Center(child: Text(company.isNotEmpty ? company[0] : '?',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: cs.primary))),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(jobTitle, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                overflow: TextOverflow.ellipsis),
            SizedBox(height: 2.h),
            Text(company, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
          ])),
          StatusBadge(status: status, t: t),
        ]),
      ),
    );
  }
}
