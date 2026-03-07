import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/edit_profile_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('settings.title')),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp),
          onPressed: () => context.pop(),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48.sp, color: cs.error),
              SizedBox(height: 12.h),
              Text(t.t('settings.load_error')),
              SizedBox(height: 12.h),
              FilledButton(
                onPressed: () => ref.read(userProvider.notifier).refresh(),
                child: Text(t.t('settings.retry')),
              ),
            ],
          ),
        ),
        data: (user) => _buildContent(context, ref, theme, cs, t, user),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    AppLocalizations t,
    Map<String, dynamic> user,
  ) {
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final pendingEmail = user['pending_email'] as String?;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        // Avatar + nom
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44.r,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                        style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              SizedBox(height: 12.h),
              Text(
                '$firstName $lastName',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2.h),
              Text(email, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (pendingEmail != null) ...[
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${t.t('settings.pending_email')}: $pendingEmail',
                    style: TextStyle(fontSize: 11.sp, color: Colors.amber[800]),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 24.h),
        // Section profil
        _SectionTitle(label: t.t('settings.section_profile')),
        _SettingsTile(
          icon: Icons.person_outline_rounded,
          title: t.t('settings.edit_profile'),
          subtitle: t.t('settings.edit_profile_sub'),
          onTap: () async {
            final changed = await showDialog<bool>(
              context: context,
              builder: (_) => EditProfileDialog(
                firstName: firstName,
                lastName: lastName,
              ),
            );
            if (changed == true) ref.read(userProvider.notifier).refresh();
          },
        ),
        // Section sécurité
        SizedBox(height: 16.h),
        _SectionTitle(label: t.t('settings.section_security')),
        _SettingsTile(
          icon: Icons.lock_outline_rounded,
          title: t.t('settings.change_password'),
          subtitle: t.t('settings.change_password_sub'),
          onTap: () async {
            final changed = await showDialog<bool>(
              context: context,
              builder: (_) => const ChangePasswordDialog(),
            );
            if (changed == true && context.mounted) {
              AppSnackbar.success(context, t.t('settings.password_changed'));
            }
          },
        ),
        _SettingsTile(
          icon: Icons.email_outlined,
          title: t.t('settings.change_email'),
          subtitle: email,
          onTap: () async {
            final changed = await showDialog<bool>(
              context: context,
              builder: (_) => ChangeEmailDialog(currentEmail: email),
            );
            if (changed == true) {
              ref.read(userProvider.notifier).refresh();
              if (context.mounted) {
                AppSnackbar.success(context, t.t('settings.email_changed'));
              }
            }
          },
        ),
        // Section compte
        SizedBox(height: 16.h),
        _SectionTitle(label: t.t('settings.section_account')),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: t.t('settings.logout'),
          subtitle: t.t('settings.logout_sub'),
          isDestructive: true,
          onTap: () async {
            await AuthService().logout();
            if (!context.mounted) return;
            context.go('/first-page');
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurface;

    return Card(
      margin: EdgeInsets.only(bottom: 6.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22.sp),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14.sp)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right_rounded, size: 20.sp, color: cs.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        onTap: onTap,
      ),
    );
  }
}
