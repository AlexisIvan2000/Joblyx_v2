import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase/phase_sections.dart';
import 'package:frontend/core/utils/haptic.dart';

/// Carte d'une phase de la roadmap avec timeline et contenu extensible.
class PhaseCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> phase;
  final bool isLast;
  final void Function(int phaseNumber)? onTogglePhaseComplete;
  final void Function(int phaseNumber, int actionIndex)? onToggleActionComplete;
  final void Function(int phaseNumber)? onDeletePhase;
  final void Function(int phaseNumber, String currentNotes)? onEditNotes;

  const PhaseCard({
    super.key,
    required this.index,
    required this.phase,
    required this.isLast,
    this.onTogglePhaseComplete,
    this.onToggleActionComplete,
    this.onDeletePhase,
    this.onEditNotes,
  });

  @override
  State<PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<PhaseCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // La première phase est ouverte par défaut
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

    final skills = _parseListOfMaps(phase['skills']);
    final actions = _parseListOfMaps(phase['actions']);
    final resources = _parseListOfMaps(phase['resources']);
    final certifications = _parseListOfMaps(phase['certifications']);
    final projects = _parseListOfMaps(phase['projects']);

    return RepaintBoundary(
      child: Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline verticale
          _buildTimeline(cs, phaseNumber, completed),
          SizedBox(width: 10.w),
          // Contenu de la carte
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () { Haptic.selection(); setState(() => _expanded = !_expanded); },
                onLongPress: _hasContextMenu
                    ? () => _showContextMenu(context, cs, t, phaseNumber, userNotes)
                    : null,
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(theme, cs, t, title, weeks, completed, custom, phaseNumber),
                        if (_expanded) ...[
                          if (objective.isNotEmpty) _buildObjective(theme, cs, objective),
                          if (userNotes.isNotEmpty) _buildNotes(theme, cs, userNotes),
                          SizedBox(height: 12.h),
                          // Compétences à apprendre
                          if (skills.isNotEmpty) _buildSkills(t, cs, skills),
                          // Actions
                          if (actions.isNotEmpty) ...[
                            SizedBox(height: 12.h),
                            PhaseActionsList(
                              actions: actions,
                              onToggle: widget.onToggleActionComplete != null
                                  ? (i) => widget.onToggleActionComplete!(phaseNumber, i)
                                  : null,
                            ),
                          ],
                          // Ressources
                          if (resources.isNotEmpty) ...[SizedBox(height: 12.h), PhaseResourcesList(resources: resources)],
                          // Certifications
                          if (certifications.isNotEmpty) ...[SizedBox(height: 12.h), PhaseCertificationsList(certifications: certifications)],
                          // Projets
                          if (projects.isNotEmpty) ...[SizedBox(height: 12.h), PhaseProjectsList(projects: projects)],
                          // Jalon
                          if (milestone.isNotEmpty) _buildMilestone(theme, cs, milestone),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  bool get _hasContextMenu => widget.onDeletePhase != null || widget.onEditNotes != null;

  // ── Sous-widgets ────────────────────────────────────────────

  Widget _buildTimeline(ColorScheme cs, int number, bool completed) {
    final color = completed ? Colors.green : cs.primary;
    return SizedBox(
      width: 32.w,
      child: Column(children: [
        Container(
          width: 28.w, height: 28.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: completed
                ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                : Text('$number', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, fontSize: 13.sp)),
          ),
        ),
        if (!widget.isLast)
          Container(width: 2.w, height: _expanded ? 400.h : 40.h, color: color.withValues(alpha: 0.3)),
      ]),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, AppLocalizations t,
      String title, int weeks, bool completed, bool custom, int phaseNumber) {
    return Row(children: [
      if (widget.onTogglePhaseComplete != null)
        GestureDetector(
          onTap: () => widget.onTogglePhaseComplete!(phaseNumber),
          child: Padding(padding: EdgeInsets.only(right: 6.w), child: Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20.sp, color: completed ? Colors.green : cs.outline,
          )),
        ),
      Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold, decoration: completed ? TextDecoration.lineThrough : null))),
      if (custom)
        Padding(padding: EdgeInsets.only(right: 4.w), child: Chip(
          label: Text(t.t('dashboard.custom_phase'), style: TextStyle(fontSize: 9.sp)),
          visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8.r)),
        child: Text('$weeks ${t.t('dashboard.weeks')}',
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
      ),
      SizedBox(width: 4.w),
      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20.sp),
    ]);
  }

  Widget _buildObjective(ThemeData theme, ColorScheme cs, String objective) {
    return Padding(padding: EdgeInsets.only(top: 10.h), child: Text(objective,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)));
  }

  Widget _buildNotes(ThemeData theme, ColorScheme cs, String notes) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Container(
        width: double.infinity, padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.sticky_note_2_outlined, size: 16.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 6.w),
          Expanded(child: Text(notes, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        ]),
      ),
    );
  }

  Widget _buildSkills(AppLocalizations t, ColorScheme cs, List<Map<String, dynamic>> skills) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PhaseSectionLabel(icon: Icons.code_rounded, label: t.t('dashboard.skills_to_learn')),
      SizedBox(height: 6.h),
      Wrap(spacing: 6.w, runSpacing: 6.h, children: skills.map((s) {
        final priority = s['priority'] as String? ?? '';
        final done = s['completed'] as bool? ?? false;
        final borderColor = switch (priority) {
          'critical' => cs.error, 'high' => cs.primary, 'medium' => cs.tertiary, _ => cs.outline,
        };
        return Chip(
          label: Text(s['name'] as String? ?? '',
              style: TextStyle(fontSize: 12.sp, decoration: done ? TextDecoration.lineThrough : null)),
          avatar: done ? Icon(Icons.check_circle, size: 16.sp, color: Colors.green) : null,
          side: BorderSide(color: borderColor),
          visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
        );
      }).toList()),
    ]);
  }

  Widget _buildMilestone(ThemeData theme, ColorScheme cs, String milestone) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Container(
        width: double.infinity, padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(children: [
          Icon(Icons.flag_rounded, size: 18.sp, color: cs.tertiary),
          SizedBox(width: 8.w),
          Expanded(child: Text(milestone,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.italic))),
        ]),
      ),
    );
  }

  // ── Menu contextuel ─────────────────────────────────────────

  void _showContextMenu(BuildContext context, ColorScheme cs, AppLocalizations t, int phaseNumber, String notes) {
    showModalBottomSheet(
      context: context, backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 8.h),
        Container(width: 36.w, height: 4.h,
            decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r))),
        SizedBox(height: 8.h),
        if (widget.onEditNotes != null)
          ListTile(
            leading: Icon(Icons.edit_note_rounded, color: cs.primary),
            title: Text(t.t('dashboard.edit_notes')),
            onTap: () { Navigator.of(context).pop(); widget.onEditNotes!(phaseNumber, notes); },
          ),
        if (widget.onDeletePhase != null)
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: cs.error),
            title: Text(t.t('dashboard.delete_phase'), style: TextStyle(color: cs.error)),
            onTap: () { Navigator.of(context).pop(); widget.onDeletePhase!(phaseNumber); },
          ),
        SizedBox(height: 8.h),
      ])),
    );
  }

  /// Parse une liste qui peut contenir des Map ou des String (rétro-compat).
  List<Map<String, dynamic>> _parseListOfMaps(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{'name': item.toString(), 'task': item.toString()};
    }).toList();
  }
}
