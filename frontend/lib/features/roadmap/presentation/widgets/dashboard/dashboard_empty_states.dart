// États vides du dashboard : EmptyRoadmapCard, EmptyApplicationsCard.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

// ─── CTA quand aucune roadmap n'existe ───────────────────────

class EmptyRoadmapCard extends StatelessWidget {
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback onGenerateAI;
  final VoidCallback onCreateManual;
  const EmptyRoadmapCard({super.key, required this.cs, required this.t, required this.onGenerateAI, required this.onCreateManual});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.85)]),
      ),
      child: Column(children: [
        Icon(Icons.route_rounded, size: 40.sp, color: Colors.white70),
        SizedBox(height: 12.h),
        Text(t.t('home.empty_roadmap_title'),
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
        SizedBox(height: 6.h),
        Text(t.t('home.empty_roadmap_subtitle'),
            style: TextStyle(fontSize: 12.sp, color: Colors.white70), textAlign: TextAlign.center),
        SizedBox(height: 20.h),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: onGenerateAI,
            icon: Icon(Icons.auto_awesome_rounded, size: 18.sp),
            label: Text(t.t('home.generate_ai'), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: cs.primary,
                minimumSize: Size(0, 44.h)),
          )),
          SizedBox(width: 10.w),
          Expanded(child: OutlinedButton.icon(
            onPressed: onCreateManual,
            icon: Icon(Icons.edit_note_rounded, size: 18.sp),
            label: Text(t.t('home.create_manual'), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54),
                minimumSize: Size(0, 44.h)),
          )),
        ]),
      ]),
    );
  }
}

// ─── CTA quand aucune candidature n'existe ───────────────────

class EmptyApplicationsCard extends StatelessWidget {
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback onTap;
  const EmptyApplicationsCard({super.key, required this.cs, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(Icons.description_outlined, size: 36.sp, color: cs.primary.withValues(alpha: 0.6)),
        SizedBox(height: 10.h),
        Text(t.t('home.empty_applications_title'),
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface), textAlign: TextAlign.center),
        SizedBox(height: 4.h),
        Text(t.t('home.empty_applications_subtitle'),
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        SizedBox(height: 14.h),
        FilledButton.icon(
          onPressed: onTap, icon: Icon(Icons.add_rounded, size: 18.sp), label: Text(t.t('home.add_application')),
          style: FilledButton.styleFrom(minimumSize: Size(0, 40.h)),
        ),
      ]),
    );
  }
}
