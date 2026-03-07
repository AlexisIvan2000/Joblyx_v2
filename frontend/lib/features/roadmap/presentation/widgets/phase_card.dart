import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

class PhaseCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> phase;
  final bool isLast;

  const PhaseCard({
    super.key,
    required this.index,
    required this.phase,
    required this.isLast,
  });

  @override
  State<PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<PhaseCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.index == 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    final phase = widget.phase;

    final title = phase['title'] as String? ?? '';
    final weeks = phase['duration_weeks'] as int? ?? 0;
    final skills = (phase['skills'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final actions = (phase['actions'] as List?)?.cast<String>() ?? [];
    final resources = (phase['resources'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final certs = (phase['certifications'] as List?)?.cast<String>() ?? [];
    final milestone = phase['milestone'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 32.w,
            child: Column(
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
                if (!widget.isLast)
                  Container(
                    width: 2.w,
                    height: _expanded ? 400.h : 40.h,
                    color: cs.primary.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Contenu
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre + durée
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '$weeks ${t.t('dashboard.weeks')}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 20.sp,
                          ),
                        ],
                      ),
                      // Contenu étendu
                      if (_expanded) ...[
                        SizedBox(height: 12.h),
                        // Skills
                        if (skills.isNotEmpty) ...[
                          _SectionLabel(icon: Icons.code_rounded, label: t.t('dashboard.skills_to_learn')),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: skills.map((s) {
                              final priority = s['priority'] as String? ?? '';
                              return Chip(
                                label: Text(s['name'] as String? ?? '', style: TextStyle(fontSize: 12.sp)),
                                side: BorderSide(
                                  color: priority == 'high'
                                      ? cs.primary
                                      : priority == 'medium'
                                          ? cs.tertiary
                                          : cs.outline,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                        // Actions
                        if (actions.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(icon: Icons.checklist_rounded, label: t.t('dashboard.actions')),
                          SizedBox(height: 4.h),
                          ...actions.map((a) => Padding(
                                padding: EdgeInsets.only(bottom: 4.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.arrow_right_rounded, size: 18.sp, color: cs.primary),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(a, style: theme.textTheme.bodySmall),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        // Ressources
                        if (resources.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(icon: Icons.menu_book_rounded, label: t.t('dashboard.resources')),
                          SizedBox(height: 4.h),
                          ...resources.map((r) {
                            final url = r['url'] as String? ?? '';
                            final rTitle = r['title'] as String? ?? '';
                            final rType = r['type'] as String? ?? '';
                            final free = r['free'] as bool? ?? false;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: InkWell(
                                onTap: url.isNotEmpty
                                    ? () => launchUrl(Uri.parse(url),
                                        mode: LaunchMode.externalApplication)
                                    : null,
                                borderRadius: BorderRadius.circular(8.r),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: Row(
                                    children: [
                                      Icon(
                                        url.isNotEmpty ? Icons.link_rounded : Icons.description_outlined,
                                        size: 16.sp,
                                        color: cs.primary,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          rTitle,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: url.isNotEmpty ? cs.primary : null,
                                            decoration: url.isNotEmpty ? TextDecoration.underline : null,
                                          ),
                                        ),
                                      ),
                                      if (rType.isNotEmpty)
                                        Text(rType, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                                      if (free)
                                        Padding(
                                          padding: EdgeInsets.only(left: 4.w),
                                          child: Icon(Icons.star_rounded, size: 14.sp, color: Colors.amber),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        // Certifications
                        if (certs.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(icon: Icons.verified_rounded, label: t.t('dashboard.certifications')),
                          SizedBox(height: 4.h),
                          ...certs.map((c) => Padding(
                                padding: EdgeInsets.only(bottom: 4.h),
                                child: Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 16.sp, color: Colors.amber),
                                    SizedBox(width: 6.w),
                                    Expanded(child: Text(c, style: theme.textTheme.bodySmall)),
                                  ],
                                ),
                              )),
                        ],
                        // Milestone
                        if (milestone.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, size: 18.sp, color: cs.tertiary),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    milestone,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: theme.colorScheme.onSurfaceVariant),
        SizedBox(width: 4.w),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
