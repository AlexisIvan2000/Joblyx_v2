import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Dialog affiché quand un compte super_admin tente d'accéder à l'app mobile.
/// Le super_admin se connecte uniquement via le panel admin.
Future<void> showAdminOnlyDialog(BuildContext context) {
  final t = AppLocalizations.of(context);
  final cs = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.admin_panel_settings_outlined, size: 32.sp, color: cs.primary),
      title: Text(t.t('auth_error.admin_only_title')),
      content: Text(t.t('auth_error.admin_only')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.t('auth_error.admin_only_action')),
        ),
      ],
    ),
  );
}
