import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('dashboard.title')),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: Icon(Icons.logout_rounded, size: 22.sp),
          ),
        ],
      ),
      body: Center(
        child: Text(
          t.t('dashboard.welcome'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}
