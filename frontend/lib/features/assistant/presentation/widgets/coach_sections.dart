import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Vue complète de l'analyse coach — utilisée par le résultat streaming et le détail historique.
class CoachAnalysisView extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final bool isStreaming;

  const CoachAnalysisView({super.key, required this.analysis, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final score = analysis['compatibility_score'] as int? ?? 0;
    final summary = analysis['summary'] as String? ?? '';
    final ats = analysis['ats_analysis'] as Map<String, dynamic>?;
    final structure = analysis['structure_analysis'] as Map<String, dynamic>?;
    final expOpt = analysis['experience_optimization'] as List?;
    final strengths = analysis['strengths'] as List?;
    final recommendations = analysis['recommendations'] as List?;
    final missingSections = analysis['missing_sections'] as List?;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          // Score de compatibilité
          CoachScoreWidget(score: score),
          SizedBox(height: 12.h),

          // Résumé
          if (summary.isNotEmpty) ...[
            Text(summary,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center),
            SizedBox(height: 20.h),
          ],

          // Shimmer placeholders si le streaming n'a pas encore tout chargé
          if (isStreaming && ats == null) ...[
            _shimmerCard(cs), _shimmerCard(cs), _shimmerCard(cs),
          ],

          // Mots-clés ATS
          if (ats != null)
            _AtsSection(ats: ats, cs: cs, t: t),

          // Structure du CV
          if (structure != null)
            _StructureSection(structure: structure, cs: cs, t: t),

          // Optimisation des expériences
          if (expOpt != null && expOpt.isNotEmpty)
            _ExperienceSection(items: expOpt, cs: cs, t: t),

          // Points forts
          if (strengths != null && strengths.isNotEmpty)
            _StrengthsSection(items: strengths, cs: cs, t: t),

          // Recommandations
          if (recommendations != null && recommendations.isNotEmpty)
            _RecommendationsSection(items: recommendations, cs: cs, t: t),

          // Sections manquantes
          if (missingSections != null && missingSections.isNotEmpty)
            _MissingSectionsWidget(items: missingSections, cs: cs, t: t),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _shimmerCard(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        height: 60.h, width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}

// ─── Score circulaire ──────────────────────────────────────────

class CoachScoreWidget extends StatelessWidget {
  final int score;
  const CoachScoreWidget({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = score >= 70
        ? const Color(0xFF5DCAA5)
        : score >= 40
            ? const Color(0xFFFFB347)
            : const Color(0xFFE57373);

    return SizedBox(
      width: 100.w, height: 100.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100.w, height: 100.w,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8.w,
              color: color,
              backgroundColor: cs.surfaceContainerHighest,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: color)),
              Text('%',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section ATS ───────────────────────────────────────────────

class _AtsSection extends StatelessWidget {
  final Map<String, dynamic> ats;
  final ColorScheme cs;
  final AppLocalizations t;

  const _AtsSection({required this.ats, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    final found = (ats['keywords_found'] as List?)?.cast<String>() ?? [];
    final missing = (ats['keywords_missing'] as List?)?.cast<String>() ?? [];
    final matchPct = ats['keyword_match_percentage'] as int? ?? 0;
    final tips = (ats['ats_tips'] as List?)?.cast<String>() ?? [];

    return _SectionTile(
      title: t.t('coach.ats_title'),
      icon: Icons.search_rounded,
      initiallyExpanded: true,
      cs: cs,
      children: [
        // Pourcentage de match
        Text('${t.t('coach.keyword_match')}: $matchPct%',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
        SizedBox(height: 10.h),

        // Keywords trouvés
        if (found.isNotEmpty) ...[
          Text(t.t('coach.keywords_found'), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF5DCAA5))),
          SizedBox(height: 4.h),
          Wrap(spacing: 6.w, runSpacing: 4.h, children: found.map((k) => _chip(k, const Color(0xFF5DCAA5), const Color(0xFFE1F5EE))).toList()),
          SizedBox(height: 10.h),
        ],

        // Keywords manquants
        if (missing.isNotEmpty) ...[
          Text(t.t('coach.keywords_missing'), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFFE57373))),
          SizedBox(height: 4.h),
          Wrap(spacing: 6.w, runSpacing: 4.h, children: missing.map((k) => _chip(k, const Color(0xFFE57373), const Color(0xFFFCE4EC))).toList()),
          SizedBox(height: 10.h),
        ],

        // Tips ATS
        ...tips.map((tip) => Padding(
          padding: EdgeInsets.only(bottom: 6.h),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded, size: 14.sp, color: cs.primary),
            SizedBox(width: 6.w),
            Expanded(child: Text(tip, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4))),
          ]),
        )),
      ],
    );
  }

  Widget _chip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8.r)),
      child: Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ─── Section Structure ─────────────────────────────────────────

class _StructureSection extends StatelessWidget {
  final Map<String, dynamic> structure;
  final ColorScheme cs;
  final AppLocalizations t;

  const _StructureSection({required this.structure, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    final formatScore = structure['format_score'] as int? ?? 0;
    final issues = (structure['issues'] as List?) ?? [];

    return _SectionTile(
      title: '${t.t('coach.structure_title')} ($formatScore/100)',
      icon: Icons.dashboard_outlined,
      cs: cs,
      children: [
        ...issues.map((issue) {
          final i = issue as Map<String, dynamic>;
          return Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, size: 14.sp, color: const Color(0xFFFFB347)),
                SizedBox(width: 6.w),
                Expanded(child: Text(i['problem'] as String? ?? '', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurface))),
              ]),
              Padding(
                padding: EdgeInsets.only(left: 20.w, top: 4.h),
                child: Text(i['fix'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4)),
              ),
            ]),
          );
        }),
      ],
    );
  }
}

// ─── Section Expériences ───────────────────────────────────────

class _ExperienceSection extends StatelessWidget {
  final List items;
  final ColorScheme cs;
  final AppLocalizations t;

  const _ExperienceSection({required this.items, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: t.t('coach.experience_title'),
      icon: Icons.swap_horiz_rounded,
      initiallyExpanded: true,
      cs: cs,
      children: items.map((item) {
        final i = item as Map<String, dynamic>;
        return Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avant
              Text(i['current'] as String? ?? '',
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, decoration: TextDecoration.lineThrough, height: 1.4)),
              SizedBox(height: 6.h),
              // Après
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF5DCAA5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFF5DCAA5).withValues(alpha: 0.3)),
                ),
                child: Text(i['optimized'] as String? ?? '',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.4)),
              ),
              // Pourquoi
              if ((i['why'] as String?)?.isNotEmpty ?? false) ...[
                SizedBox(height: 6.h),
                Text(i['why'] as String, style: TextStyle(fontSize: 11.sp, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, height: 1.3)),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section Points forts ──────────────────────────────────────

class _StrengthsSection extends StatelessWidget {
  final List items;
  final ColorScheme cs;
  final AppLocalizations t;

  const _StrengthsSection({required this.items, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: t.t('coach.strengths_title'),
      icon: Icons.thumb_up_outlined,
      cs: cs,
      children: items.map((item) {
        final i = item as Map<String, dynamic>;
        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle_rounded, size: 16.sp, color: const Color(0xFF5DCAA5)),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i['point'] as String? ?? '', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                if ((i['detail'] as String?)?.isNotEmpty ?? false)
                  Text(i['detail'] as String, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3)),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ─── Section Recommandations ───────────────────────────────────

class _RecommendationsSection extends StatelessWidget {
  final List items;
  final ColorScheme cs;
  final AppLocalizations t;

  const _RecommendationsSection({required this.items, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    // Trier par priorité
    final sorted = List.from(items)
      ..sort((a, b) {
        const order = {'critical': 0, 'high': 1, 'medium': 2};
        final pa = order[(a as Map)['priority']] ?? 2;
        final pb = order[(b as Map)['priority']] ?? 2;
        return pa.compareTo(pb);
      });

    return _SectionTile(
      title: t.t('coach.recommendations_title'),
      icon: Icons.lightbulb_outline_rounded,
      cs: cs,
      children: sorted.map((item) {
        final i = item as Map<String, dynamic>;
        final priority = i['priority'] as String? ?? 'medium';

        final badgeColor = priority == 'critical'
            ? const Color(0xFFE57373)
            : priority == 'high'
                ? const Color(0xFFFFB347)
                : cs.onSurfaceVariant;

        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4.r)),
                  child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: badgeColor)),
                ),
                SizedBox(width: 8.w),
                Expanded(child: Text(i['title'] as String? ?? '', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.onSurface))),
              ]),
              if ((i['problem'] as String?)?.isNotEmpty ?? false) ...[
                SizedBox(height: 6.h),
                Text(i['problem'] as String, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3)),
              ],
              if ((i['suggestion'] as String?)?.isNotEmpty ?? false) ...[
                SizedBox(height: 6.h),
                Text(i['suggestion'] as String, style: TextStyle(fontSize: 11.sp, color: cs.onSurface, height: 1.3)),
              ],
              if ((i['impact'] as String?)?.isNotEmpty ?? false) ...[
                SizedBox(height: 4.h),
                Text('Impact: ${i['impact']}', style: TextStyle(fontSize: 10.sp, fontStyle: FontStyle.italic, color: cs.primary)),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Sections manquantes ───────────────────────────────────────

class _MissingSectionsWidget extends StatelessWidget {
  final List items;
  final ColorScheme cs;
  final AppLocalizations t;

  const _MissingSectionsWidget({required this.items, required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    return _SectionTile(
      title: t.t('coach.missing_sections_title'),
      icon: Icons.add_circle_outline_rounded,
      cs: cs,
      children: items.map((item) {
        final i = item as Map<String, dynamic>;
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i['section'] as String? ?? '', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
            if ((i['why'] as String?)?.isNotEmpty ?? false) ...[
              SizedBox(height: 3.h),
              Text(i['why'] as String, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3)),
            ],
            if ((i['example'] as String?)?.isNotEmpty ?? false) ...[
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8.r)),
                child: Text(i['example'] as String, style: TextStyle(fontSize: 11.sp, color: cs.onSurface, fontFamily: 'monospace', height: 1.3)),
              ),
            ],
          ]),
        );
      }).toList(),
    );
  }
}

// ─── Widget de section pliable ─────────────────────────────────

class _SectionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _SectionTile({
    required this.title,
    required this.icon,
    required this.cs,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, size: 20.sp, color: cs.primary),
          title: Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
          childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
          children: children,
        ),
      ),
    );
  }
}
