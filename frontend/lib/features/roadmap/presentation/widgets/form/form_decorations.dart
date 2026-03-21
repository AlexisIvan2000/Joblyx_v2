import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Border radius commun pour tous les champs de formulaire.
final _radius = BorderRadius.circular(30.r);

/// Décoration standard pour les champs de saisie du formulaire.
InputDecoration inputDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, size: 20.sp) : null,
    filled: true,
    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
    border: OutlineInputBorder(borderRadius: _radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: _radius, borderSide: BorderSide(color: cs.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: _radius, borderSide: BorderSide(color: cs.error, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: _radius, borderSide: BorderSide(color: cs.error, width: 1.5)),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
  );
}

/// Décoration pour les menus déroulants (padding vertical réduit).
InputDecoration dropdownDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
}) {
  return inputDecoration(context, label: label, icon: icon).copyWith(
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
  );
}
