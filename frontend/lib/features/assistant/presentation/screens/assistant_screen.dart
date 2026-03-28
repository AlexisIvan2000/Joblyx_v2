import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';
import 'package:frontend/core/widgets/staggered_list.dart';
import 'package:frontend/core/utils/haptic.dart';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final usageAsync = ref.watch(coachUsageProvider);
    final historyAsync = ref.watch(coachHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('assistant.title'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: StaggeredList(
          children: [
          // Carte Coach IA
          _AssistantCard(
            icon: Icons.description_outlined,
            iconColor: cs.primary,
            title: t.t('assistant.coach_title'),
            subtitle: t.t('assistant.coach_subtitle'),
            trailing: usageAsync.when(
              data: (usage) => Text(
                '${usage['used']}/${usage['limit']} ${t.t('assistant.coach_period')}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              loading: () => SizedBox(width: 14.w, height: 14.w, child: const CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
            ),
            onTap: () { Haptic.medium(); context.push('/assistant/coach'); },
            cs: cs,
          ),
          SizedBox(height: 10.h),

          // Carte Simulateur d'entretien
          _AssistantCard(
            icon: Icons.chat_outlined,
            iconColor: cs.tertiary,
            title: t.t('assistant.simulator_title'),
            subtitle: t.t('assistant.simulator_subtitle'),
            trailing: ref.watch(interviewUsageProvider).when(
              data: (usage) => Text(
                '${usage['used']}/${usage['limit']} ${t.t('assistant.simulator_period')}',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.tertiary),
              ),
              loading: () => SizedBox(width: 14.w, height: 14.w, child: const CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const SizedBox.shrink(),
            ),
            onTap: () { Haptic.medium(); context.push('/assistant/interview'); },
            cs: cs,
          ),
          SizedBox(height: 24.h),

          // Historique récent
          Row(
            children: [
              Expanded(
                child: Text(
                  t.t('assistant.recent_history'),
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/assistant/coach/history'),
                child: Text(t.t('assistant.view_all'),
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          historyAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: Center(
                    child: Text(
                      t.t('assistant.no_history'),
                      style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return StaggeredList(
                children: sessions.take(3).map((s) => _HistoryTile(session: s, cs: cs)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ColorScheme cs;

  const _AssistantCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 44.w, height: 44.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 24.sp, color: iconColor),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      SizedBox(height: 3.h),
                      Text(subtitle, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final ColorScheme cs;

  const _HistoryTile({required this.session, required this.cs});

  @override
  Widget build(BuildContext context) {
    final score = session['compatibility_score'] as int? ?? 0;
    final jobTitle = session['job_title'] as String? ?? '';
    final company = session['company_name'] as String? ?? '';
    final createdAt = session['created_at'] as String? ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    final scoreColor = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
            ? const Color(0xFFFFB347)
            : const Color(0xFFE57373);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/assistant/coach/${session['id']}'),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // Score circulaire
              Container(
                width: 40.w, height: 40.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: scoreColor),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (jobTitle.isNotEmpty)
                      Text(jobTitle, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (company.isNotEmpty)
                      Text(company, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(dateStr, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
