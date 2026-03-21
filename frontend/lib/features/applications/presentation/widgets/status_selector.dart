import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/constants/application_status.dart';

/// Grille de sélection de statut pour les formulaires de candidature.
/// Affiche les 10 statuts avec leurs couleurs, sélection unique.
class StatusSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const StatusSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: ApplicationStatuses.all.map((cfg) {
        final isSelected = cfg.key == current;
        return GestureDetector(
          onTap: () => onChanged(cfg.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: isSelected ? cfg.bgColor : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected ? cfg.borderColor : Colors.transparent,
              ),
            ),
            child: Text(
              t.t('applications_screen.status_${cfg.key}'),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? cfg.textColor : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
