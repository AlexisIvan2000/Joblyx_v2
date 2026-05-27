import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';


// PhaseSectionLabel


/// Label de section dans une PhaseCard (ex: "Compétences", "Actions").
class PhaseSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const PhaseSectionLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: cs.onSurfaceVariant),
        SizedBox(width: 4.w),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}


// PhaseActionsList


/// Liste des actions à réaliser dans une phase, avec checkbox.
class PhaseActionsList extends StatelessWidget {
  final List<Map<String, dynamic>> actions;

  /// Callback appelé avec l'index de l'action lorsqu'on la coche/décoche.
  final void Function(int actionIndex)? onToggle;

  const PhaseActionsList({super.key, required this.actions, this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseSectionLabel(icon: Icons.checklist_rounded, label: t.t('dashboard.actions')),
        SizedBox(height: 4.h),
        ...List.generate(actions.length, (i) {
          final a = actions[i];
          final task = a['task'] as String? ?? '';
          final detail = a['detail'] as String? ?? '';
          final hours = a['estimated_hours'] as int?;
          final done = a['completed'] as bool? ?? false;

          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: InkWell(
              onTap: onToggle != null ? () => onToggle!(i) : null,
              borderRadius: BorderRadius.circular(6.r),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône cochée ou non selon l'état de l'action
                  Icon(
                    done ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18.sp,
                    color: done ? Colors.green : cs.outline,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task,
                          style: theme.textTheme.bodySmall?.copyWith(
                              decoration: done ? TextDecoration.lineThrough : null),
                        ),
                        if (detail.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 2.h),
                            child: Text(
                              detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.sp, color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Durée estimée en heures
                  if (hours != null)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Text(
                        '${hours}h',
                        style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}


// PhaseResourcesList


/// Liste des ressources d'apprentissage d'une phase.
class PhaseResourcesList extends StatelessWidget {
  final List<Map<String, dynamic>> resources;

  const PhaseResourcesList({super.key, required this.resources});

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseSectionLabel(icon: Icons.menu_book_rounded, label: t.t('dashboard.resources')),
        SizedBox(height: 4.h),
        ...resources.map((r) {
          final url = r['url'] as String? ?? '';
          final title = r['title'] as String? ?? '';
          final platform = r['platform'] as String? ?? '';
          final type = r['type'] as String? ?? '';
          // Ressource gratuite signalée par une étoile
          final free = r['free'] as bool? ?? false;

          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: InkWell(
              onTap: url.isNotEmpty
                  ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                  : null,
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(children: [
                  Icon(
                    url.isNotEmpty ? Icons.link_rounded : Icons.description_outlined,
                    size: 16.sp,
                    color: cs.primary,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: url.isNotEmpty ? cs.primary : null,
                          decoration: url.isNotEmpty ? TextDecoration.underline : null,
                        ),
                      ),
                      if (platform.isNotEmpty)
                        Text(platform,
                            style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  if (type.isNotEmpty)
                    Text(type, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                  if (free)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Icon(Icons.star_rounded, size: 14.sp, color: Colors.amber),
                    ),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }
}


// PhaseCertificationsList


/// Liste des certifications recommandées dans une phase.
class PhaseCertificationsList extends StatelessWidget {
  final List<Map<String, dynamic>> certifications;

  const PhaseCertificationsList({super.key, required this.certifications});

  @override
  Widget build(BuildContext context) {
    if (certifications.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseSectionLabel(icon: Icons.verified_rounded, label: t.t('dashboard.certifications')),
        SizedBox(height: 4.h),
        ...certifications.map((c) {
          final name = c['name'] as String? ?? '';
          final provider = c['provider'] as String? ?? '';
          final cost = c['cost'] as String? ?? '';

          return Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(children: [
              // Médaille dorée pour chaque certification
              Icon(Icons.workspace_premium_rounded, size: 16.sp, color: Colors.amber),
              SizedBox(width: 6.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: theme.textTheme.bodySmall),
                  if (provider.isNotEmpty)
                    Text(
                      '$provider${cost.isNotEmpty ? ' · $cost' : ''}',
                      style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant),
                    ),
                ]),
              ),
            ]),
          );
        }),
      ],
    );
  }
}


// PhaseProjectsList


/// Liste des projets pratiques d'une phase.
class PhaseProjectsList extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const PhaseProjectsList({super.key, required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseSectionLabel(icon: Icons.build_circle_outlined, label: t.t('dashboard.projects')),
        SizedBox(height: 4.h),
        ...projects.map((p) {
          final name = p['name'] as String? ?? '';
          final desc = p['description'] as String? ?? '';
          // Extraction des technologies associées au projet
          final techs = (p['technologies'] as List?)?.cast<String>() ?? [];

          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              if (desc.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    desc,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11.sp, color: cs.onSurfaceVariant),
                  ),
                ),
              // Chips des technologies utilisées dans le projet
              if (techs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Wrap(
                    spacing: 4.w,
                    runSpacing: 4.h,
                    children: techs
                        .map((tech) => Chip(
                              label: Text(tech, style: TextStyle(fontSize: 10.sp)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ),
            ]),
          );
        }),
      ],
    );
  }
}
