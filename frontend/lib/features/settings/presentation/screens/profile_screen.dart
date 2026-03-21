import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/core/widgets/staggered_list.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';
import 'package:frontend/features/settings/presentation/widgets/edit_profile_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final userAsync = ref.watch(userProvider);
    final regenAsync = ref.watch(regenerationStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: userAsync.when(
          loading: () => const ProfileSkeleton(),
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
          data: (user) => _buildContent(context, ref, cs, t, user, regenAsync),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    AppLocalizations t,
    Map<String, dynamic> user,
    AsyncValue<Map<String, dynamic>> regenAsync,
  ) {
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final regenRemaining = (regenAsync.whenOrNull(data: (s) => s['remaining']) ?? 0) as int;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(userProvider.notifier).refresh();
        ref.read(regenerationStatusProvider.notifier).refresh();
      },
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        children: [
          StaggeredList(
            children: [
          // Titre
          Text(t.t('profile_screen.title'),
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
          SizedBox(height: 24.h),

          // Avatar + nom + email
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48.r,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                          style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w800, color: cs.primary),
                        )
                      : null,
                ),
                SizedBox(height: 14.h),
                Text('$firstName $lastName',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
                SizedBox(height: 4.h),
                Text(email, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Stats row
          Row(
            children: [
              _StatBox(
                value: '$regenRemaining',
                label: t.t('profile_screen.regenerations_left'),
                cs: cs,
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Menu items
          _MenuItem(
            icon: Icons.person_outline_rounded,
            title: t.t('profile_screen.personal_info'),
            subtitle: t.t('profile_screen.personal_info_sub'),
            cs: cs,
            onTap: () async {
              final changed = await showDialog<bool>(
                context: context,
                builder: (_) => EditProfileDialog(firstName: firstName, lastName: lastName),
              );
              if (changed == true) ref.read(userProvider.notifier).refresh();
            },
          ),
          _MenuItem(
            icon: Icons.work_outline_rounded,
            title: t.t('profile_screen.career_profile'),
            subtitle: t.t('profile_screen.career_profile_sub'),
            cs: cs,
            onTap: () => context.push('/profile/career'),
          ),
          _MenuItem(
            icon: Icons.lock_outline_rounded,
            title: t.t('profile_screen.security'),
            subtitle: t.t('profile_screen.security_sub'),
            cs: cs,
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
          _MenuItem(
            icon: Icons.email_outlined,
            title: t.t('settings.change_email'),
            subtitle: email,
            cs: cs,
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
          _MenuItem(
            icon: Icons.language_rounded,
            title: t.t('profile_screen.language'),
            subtitle: t.t('profile_screen.language_sub'),
            cs: cs,
            onTap: () {
              // TODO: language picker
            },
          ),
          _MenuItem(
            icon: Icons.notifications_none_rounded,
            title: t.t('profile_screen.notifications'),
            subtitle: t.t('profile_screen.notifications_sub'),
            cs: cs,
            onTap: () {
              // TODO: notification settings
            },
          ),
          _MenuItem(
            icon: Icons.description_outlined,
            title: t.t('profile_screen.my_cvs'),
            subtitle: t.t('profile_screen.my_cvs_sub'),
            cs: cs,
            onTap: () {
              // TODO: CVs list
            },
          ),
          SizedBox(height: 16.h),

          // Logout
          _LogoutButton(cs: cs, t: t),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final ColorScheme cs;
  const _StatBox({required this.value, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(value,
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: cs.primary)),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 20.sp, color: cs.primary),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      SizedBox(height: 2.h),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20.sp, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final ColorScheme cs;
  final AppLocalizations t;
  const _LogoutButton({required this.cs, required this.t});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () async {
          await AuthService().logout();
          if (!context.mounted) return;
          context.go('/first-page');
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20.sp, color: cs.error),
              SizedBox(width: 8.w),
              Text(t.t('profile_screen.logout'),
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.error)),
            ],
          ),
        ),
      ),
    );
  }
}
