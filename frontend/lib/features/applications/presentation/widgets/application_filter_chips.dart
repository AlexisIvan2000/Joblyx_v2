import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Ligne de chips pour filtrer par statut.
class StatusFilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const StatusFilterChips({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    final filters = [
      ('all', t.t('applications_screen.filter_all')),
      ('active', t.t('applications_screen.filter_active')),
      ('interviews', t.t('applications_screen.filter_interviews')),
      ('closed', t.t('applications_screen.filter_closed')),
    ];

    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => SizedBox(width: 6.w),
        itemBuilder: (context, index) {
          final (key, label) = filters[index];
          return _Chip(
            label: label,
            isActive: key == current,
            onTap: () => onChanged(key),
          );
        },
      ),
    );
  }
}

/// Ligne de chips pour filtrer par période.
class TimeFilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const TimeFilterChips({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    final filters = [
      ('all_time', t.t('applications_screen.time_all')),
      ('today', t.t('applications_screen.time_today')),
      ('7d', t.t('applications_screen.time_7d')),
      ('30d', t.t('applications_screen.time_30d')),
    ];

    return SizedBox(
      height: 32.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => SizedBox(width: 6.w),
        itemBuilder: (context, index) {
          final (key, label) = filters[index];
          return _Chip(
            label: label,
            isActive: key == current,
            onTap: () => onChanged(key),
            small: true,
          );
        },
      ),
    );
  }
}

/// Chip individuel réutilisable.
class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool small;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isActive ? cs.onSurface : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10.w : 14.w,
            vertical: small ? 5.h : 7.h,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: small ? 11.sp : 12.sp,
              fontWeight: FontWeight.w600,
              color: isActive ? cs.surface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
