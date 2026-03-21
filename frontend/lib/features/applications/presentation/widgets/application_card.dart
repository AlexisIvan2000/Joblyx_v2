import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/constants/application_status.dart';

/// Carte d'une candidature dans la liste principale.
/// Affiche l'avatar entreprise, le poste, le statut coloré et la date.
class ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ApplicationCard({
    super.key,
    required this.app,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final status = (app['status'] ?? 'saved').toString();
    final cfg = ApplicationStatuses.fromKey(status);
    final company = (app['company_name'] ?? '').toString();
    final job = (app['job_title'] ?? '').toString();
    final initial = company.isNotEmpty ? company[0].toUpperCase() : '?';

    // Calcul du nombre de jours depuis la candidature
    final appliedAt = DateTime.tryParse(app['applied_at'] ?? '');
    final daysAgo = appliedAt != null ? DateTime.now().difference(appliedAt).inDays : 0;
    final daysLabel = daysAgo == 0
        ? t.t('applications_screen.time_today')
        : '$daysAgo${t.t('applications_screen.days_ago')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 44.w, 14.h),
              child: Row(
                children: [
                  // Avatar avec initiale de l'entreprise
                  Container(
                    width: 44.r, height: 44.r,
                    decoration: BoxDecoration(color: cfg.bgColor, shape: BoxShape.circle),
                    child: Center(
                      child: Text(initial,
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: cfg.textColor)),
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Titre du poste + entreprise
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job,
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text(company,
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Badge statut + date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: cfg.bgColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: cfg.borderColor),
                        ),
                        child: Text(t.t('applications_screen.status_$status'),
                            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: cfg.textColor)),
                      ),
                      SizedBox(height: 6.h),
                      Text(daysLabel, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),

            // Bouton poubelle discret
            Positioned(
              top: 4.h, right: 4.w,
              child: GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(Icons.delete_outline_rounded, size: 17.sp, color: cs.outlineVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
