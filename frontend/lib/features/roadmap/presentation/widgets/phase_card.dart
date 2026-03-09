import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

class PhaseCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> phase;
  final bool isLast;

  /// Callbacks pour toggle completion
  final void Function(int phaseNumber)? onTogglePhaseComplete;
  final void Function(int phaseNumber, int actionIndex)? onToggleActionComplete;

  const PhaseCard({
    super.key,
    required this.index,
    required this.phase,
    required this.isLast,
    this.onTogglePhaseComplete,
    this.onToggleActionComplete,
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

    final phaseNumber = phase['phase_number'] as int? ?? (widget.index + 1);
    final title = phase['title'] as String? ?? '';
    final weeks = phase['duration_weeks'] as int? ?? 0;
    final objective = phase['objective'] as String? ?? '';
    final completed = phase['completed'] as bool? ?? false;
    final custom = phase['custom'] as bool? ?? false;
    final userNotes = phase['user_notes'] as String? ?? '';
    final milestone = phase['milestone'] as String? ?? '';

    // Skills — liste d'objets {name, priority, reason, completed}
    final skills = _parseListOfMaps(phase['skills']);
    // Actions — liste d'objets {task, detail, estimated_hours, completed}
    final actions = _parseListOfMaps(phase['actions']);
    // Resources — liste d'objets {title, platform, url, type, free, why}
    final resources = _parseListOfMaps(phase['resources']);
    // Certifications — liste d'objets {name, provider, cost, value}
    final certifications = _parseListOfMaps(phase['certifications']);
    // Projects — liste d'objets {name, description, technologies, portfolio_worthy}
    final projects = _parseListOfMaps(phase['projects']);

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
                    color: completed ? Colors.green : cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: completed
                        ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                        : Text(
                            '$phaseNumber',
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
                    color: completed
                        ? Colors.green.withValues(alpha: 0.3)
                        : cs.primary.withValues(alpha: 0.3),
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
                      // Titre + durée + toggle
                      Row(
                        children: [
                          // Checkbox pour toggle completion
                          if (widget.onTogglePhaseComplete != null)
                            GestureDetector(
                              onTap: () => widget.onTogglePhaseComplete!(phaseNumber),
                              child: Padding(
                                padding: EdgeInsets.only(right: 6.w),
                                child: Icon(
                                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 20.sp,
                                  color: completed ? Colors.green : cs.outline,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (custom)
                            Padding(
                              padding: EdgeInsets.only(right: 4.w),
                              child: Chip(
                                label: Text(t.t('dashboard.custom_phase'),
                                    style: TextStyle(fontSize: 9.sp)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        // Objectif
                        if (objective.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          Text(
                            objective,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        // Notes utilisateur
                        if (userNotes.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.sticky_note_2_outlined,
                                    size: 16.sp, color: cs.onSurfaceVariant),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    userNotes,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 12.h),
                        // Skills
                        if (skills.isNotEmpty) ...[
                          _SectionLabel(
                              icon: Icons.code_rounded,
                              label: t.t('dashboard.skills_to_learn')),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: skills.map((s) {
                              final priority = s['priority'] as String? ?? '';
                              final skillCompleted = s['completed'] as bool? ?? false;
                              return Chip(
                                label: Text(
                                  s['name'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    decoration: skillCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                avatar: skillCompleted
                                    ? Icon(Icons.check_circle,
                                        size: 16.sp, color: Colors.green)
                                    : null,
                                side: BorderSide(
                                  color: priority == 'critical'
                                      ? cs.error
                                      : priority == 'high'
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
                          _SectionLabel(
                              icon: Icons.checklist_rounded,
                              label: t.t('dashboard.actions')),
                          SizedBox(height: 4.h),
                          ...List.generate(actions.length, (i) {
                            final a = actions[i];
                            final task = a['task'] as String? ?? '';
                            final detail = a['detail'] as String? ?? '';
                            final hours = a['estimated_hours'] as int?;
                            final actionCompleted = a['completed'] as bool? ?? false;
                            final phaseNum = phaseNumber;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: InkWell(
                                onTap: widget.onToggleActionComplete != null
                                    ? () => widget.onToggleActionComplete!(phaseNum, i)
                                    : null,
                                borderRadius: BorderRadius.circular(6.r),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      actionCompleted
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      size: 18.sp,
                                      color: actionCompleted ? Colors.green : cs.outline,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              decoration: actionCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          if (detail.isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(top: 2.h),
                                              child: Text(
                                                detail,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontSize: 11.sp,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hours != null)
                                      Padding(
                                        padding: EdgeInsets.only(left: 4.w),
                                        child: Text(
                                          '${hours}h',
                                          style: TextStyle(
                                              fontSize: 10.sp,
                                              color: cs.onSurfaceVariant),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        // Ressources
                        if (resources.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(
                              icon: Icons.menu_book_rounded,
                              label: t.t('dashboard.resources')),
                          SizedBox(height: 4.h),
                          ...resources.map((r) {
                            final url = r['url'] as String? ?? '';
                            final rTitle = r['title'] as String? ?? '';
                            final platform = r['platform'] as String? ?? '';
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
                                        url.isNotEmpty
                                            ? Icons.link_rounded
                                            : Icons.description_outlined,
                                        size: 16.sp,
                                        color: cs.primary,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rTitle,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: url.isNotEmpty ? cs.primary : null,
                                                decoration: url.isNotEmpty
                                                    ? TextDecoration.underline
                                                    : null,
                                              ),
                                            ),
                                            if (platform.isNotEmpty)
                                              Text(
                                                platform,
                                                style: TextStyle(
                                                    fontSize: 10.sp,
                                                    color: cs.onSurfaceVariant),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (rType.isNotEmpty)
                                        Text(rType,
                                            style: TextStyle(
                                                fontSize: 10.sp,
                                                color: cs.onSurfaceVariant)),
                                      if (free)
                                        Padding(
                                          padding: EdgeInsets.only(left: 4.w),
                                          child: Icon(Icons.star_rounded,
                                              size: 14.sp, color: Colors.amber),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        // Certifications
                        if (certifications.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(
                              icon: Icons.verified_rounded,
                              label: t.t('dashboard.certifications')),
                          SizedBox(height: 4.h),
                          ...certifications.map((c) {
                            final name = c['name'] as String? ?? '';
                            final provider = c['provider'] as String? ?? '';
                            final cost = c['cost'] as String? ?? '';

                            return Padding(
                              padding: EdgeInsets.only(bottom: 4.h),
                              child: Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded,
                                      size: 16.sp, color: Colors.amber),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: theme.textTheme.bodySmall),
                                        if (provider.isNotEmpty)
                                          Text(
                                            '$provider${cost.isNotEmpty ? ' · $cost' : ''}',
                                            style: TextStyle(
                                                fontSize: 10.sp,
                                                color: cs.onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        // Projects
                        if (projects.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _SectionLabel(
                              icon: Icons.build_circle_outlined,
                              label: t.t('dashboard.projects')),
                          SizedBox(height: 4.h),
                          ...projects.map((p) {
                            final name = p['name'] as String? ?? '';
                            final desc = p['description'] as String? ?? '';
                            final techs =
                                (p['technologies'] as List?)?.cast<String>() ?? [];

                            return Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontWeight: FontWeight.w600)),
                                  if (desc.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.h),
                                      child: Text(desc,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 11.sp,
                                              color: cs.onSurfaceVariant)),
                                    ),
                                  if (techs.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: Wrap(
                                        spacing: 4.w,
                                        runSpacing: 4.h,
                                        children: techs
                                            .map((tech) => Chip(
                                                  label: Text(tech,
                                                      style:
                                                          TextStyle(fontSize: 10.sp)),
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
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
                                Icon(Icons.flag_rounded,
                                    size: 18.sp, color: cs.tertiary),
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

  /// Parse une liste qui peut contenir des Map ou des String (rétro-compat)
  List<Map<String, dynamic>> _parseListOfMaps(dynamic raw) {
    if (raw == null) return [];
    final list = raw as List;
    return list.map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      // Rétro-compatibilité : si c'est une string, on la wrappe
      return <String, dynamic>{'name': item.toString(), 'task': item.toString()};
    }).toList();
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
