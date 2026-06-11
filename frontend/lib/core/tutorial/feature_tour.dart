import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/tutorial/tutorial_keys.dart';

const _keyTooltipsSeen = 'tooltips_seen';

/// Vrai si l'utilisateur a déjà vu le tour guidé.
Future<bool> hasSeenTour() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyTooltipsSeen) ?? false;
}

/// Réinitialise le tour pour qu'il se rejoue au prochain lancement.
Future<void> resetTour() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyTooltipsSeen);
}

Future<void> _markSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyTooltipsSeen, true);
}

/// Définition d'une étape du tour, avant filtrage des éléments absents.
class _Step {
  final GlobalKey key;
  final String titleKey;
  final String descKey;
  final ContentAlign align;
  final ShapeLightFocus shape;

  const _Step(this.key, this.titleKey, this.descKey, this.align, this.shape);
}

/// Affiche le tour guidé sur les éléments actuellement présents à l'écran.
/// Persiste `tooltips_seen` à la fin ou au skip pour ne le montrer qu'une fois.
void showFeatureTour(BuildContext context) {
  final keys = TutorialKeys.instance;
  final t = AppLocalizations.of(context);
  final cs = Theme.of(context).colorScheme;

  // Onglets en bas : bulle au-dessus. Cartes : bulle en dessous.
  final steps = <_Step>[
    _Step(keys.navHome, 'tutorial.nav_home_title', 'tutorial.nav_home_desc', ContentAlign.top, ShapeLightFocus.Circle),
    _Step(keys.navRoadmap, 'tutorial.nav_roadmap_title', 'tutorial.nav_roadmap_desc', ContentAlign.top, ShapeLightFocus.Circle),
    _Step(keys.navApplications, 'tutorial.nav_applications_title', 'tutorial.nav_applications_desc', ContentAlign.top, ShapeLightFocus.Circle),
    _Step(keys.navAssistant, 'tutorial.nav_assistant_title', 'tutorial.nav_assistant_desc', ContentAlign.top, ShapeLightFocus.Circle),
    _Step(keys.navProfile, 'tutorial.nav_profile_title', 'tutorial.nav_profile_desc', ContentAlign.top, ShapeLightFocus.Circle),
    _Step(keys.statsCard, 'tutorial.stats_title', 'tutorial.stats_desc', ContentAlign.bottom, ShapeLightFocus.RRect),
    _Step(keys.roadmapCard, 'tutorial.roadmap_title', 'tutorial.roadmap_desc', ContentAlign.bottom, ShapeLightFocus.RRect),
    _Step(keys.currentPhase, 'tutorial.phase_title', 'tutorial.phase_desc', ContentAlign.top, ShapeLightFocus.RRect),
  ];

  // Ne garde que les éléments réellement rendus (ex. pas de roadmap au 1er lancement)
  final present = steps.where((s) => s.key.currentContext != null).toList();
  if (present.isEmpty) {
    _markSeen();
    return;
  }

  final targets = <TargetFocus>[
    for (var i = 0; i < present.length; i++)
      _buildTarget(present[i], t, cs, isLast: i == present.length - 1),
  ];

  TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.82,
    paddingFocus: 8,
    hideSkip: true,
    onFinish: _markSeen,
    onSkip: () {
      _markSeen();
      return true;
    },
  ).show(context: context);
}

TargetFocus _buildTarget(
  _Step step,
  AppLocalizations t,
  ColorScheme cs, {
  required bool isLast,
}) {
  return TargetFocus(
    identify: step.key.toString(),
    keyTarget: step.key,
    shape: step.shape,
    radius: 14,
    // Anneau coloré pour que la mise en évidence ressorte, même sur fond clair (bottom nav)
    borderSide: BorderSide(color: cs.primary, width: 3),
    contents: [
      TargetContent(
        align: step.align,
        builder: (context, controller) => _TourBubble(
          title: t.t(step.titleKey),
          description: t.t(step.descKey),
          nextLabel: isLast ? t.t('tutorial.finish') : t.t('tutorial.next'),
          skipLabel: t.t('tutorial.skip'),
          showSkip: !isLast,
          onNext: controller.next,
          onSkip: controller.skip,
          cs: cs,
        ),
      ),
    ],
  );
}

/// Bulle explicative affichée à côté de l'élément mis en évidence.
class _TourBubble extends StatelessWidget {
  final String title;
  final String description;
  final String nextLabel;
  final String skipLabel;
  final bool showSkip;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final ColorScheme cs;

  const _TourBubble({
    required this.title,
    required this.description,
    required this.nextLabel,
    required this.skipLabel,
    required this.showSkip,
    required this.onNext,
    required this.onSkip,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 280.w),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment:
                  showSkip ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              children: [
                if (showSkip)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(skipLabel),
                  ),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  ),
                  child: Text(nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
