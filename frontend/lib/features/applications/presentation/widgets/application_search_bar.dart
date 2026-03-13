import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Barre de recherche pour filtrer les candidatures par nom d'entreprise ou poste.
class ApplicationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const ApplicationSearchBar({
    super.key,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t.t('applications_screen.search_hint'),
        hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
        prefixIcon: Icon(Icons.search_rounded, size: 20.sp, color: cs.onSurfaceVariant),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18.sp, color: cs.onSurfaceVariant),
                onPressed: onClear,
              )
            : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
