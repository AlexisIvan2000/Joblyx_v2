import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/core/widgets/staggered_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';
import 'package:frontend/features/settings/presentation/utils/invalidate_providers.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/core/utils/haptic.dart';
import 'package:frontend/features/settings/presentation/widgets/edit_profile_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/set_password_dialog.dart';
import 'package:frontend/features/settings/presentation/widgets/change_email_dialog.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final userAsync = ref.watch(userProvider);
    final regenAsync = ref.watch(regenerationStatusProvider);
    final appsAsync = ref.watch(applicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('profile_screen.title')),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_rounded, size: 22.sp),
          ),
        ],
      ),
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
          data: (user) => _buildContent(context, ref, cs, t, user, regenAsync, appsAsync),
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
    AsyncValue<List<Map<String, dynamic>>> appsAsync,
  ) {
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final hasPassword = user['has_password'] as bool? ?? true;
    final regenRemaining = (regenAsync.whenOrNull(data: (s) => s['remaining']) ?? 0) as int;
    final totalApps = appsAsync.whenOrNull(data: (apps) => apps.length) ?? 0;
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(userProvider.notifier).refresh();
        ref.read(regenerationStatusProvider.notifier).refresh();
        ref.read(applicationsProvider.notifier).refresh();
      },
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        children: [
          StaggeredList(
            children: [
              // Avatar + nom + email
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48.r,
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(initials,
                                  style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w800, color: cs.primary))
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: () { Haptic.medium(); _showPhotoPickerDialog(context, ref, cs, t); },
                            child: Container(
                              width: 32.r, height: 32.r,
                              decoration: BoxDecoration(
                                color: cs.primary, shape: BoxShape.circle,
                                border: Border.all(color: cs.surface, width: 2),
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 16.sp, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Text('$firstName $lastName',
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
                    SizedBox(height: 4.h),
                    Text(email,
                        style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Stats : régénérations + candidatures
              Row(
                children: [
                  _StatBox(value: '$regenRemaining', label: t.t('profile_screen.regenerations_left'), cs: cs),
                  SizedBox(width: 10.w),
                  _StatBox(value: '$totalApps', label: t.t('profile_screen.total_applications'), cs: cs),
                ],
              ),
              SizedBox(height: 24.h),

              // Informations personnelles
              _MenuItem(
                icon: Icons.person_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                title: t.t('profile_screen.personal_info'),
                subtitle: t.t('profile_screen.personal_info_sub'),
                cs: cs,
                onTap: () async {
                  final result = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (_) => EditProfileDialog(firstName: firstName, lastName: lastName),
                  );
                  if (result != null) {
                    ref.read(userProvider.notifier).updateName(
                      firstName: result['first_name']!,
                      lastName: result['last_name']!,
                    );
                  }
                },
              ),

              // Profil carrière
              _MenuItem(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF059669),
                title: t.t('profile_screen.career_profile'),
                subtitle: t.t('profile_screen.career_profile_sub'),
                cs: cs,
                onTap: () => context.push('/profile/career'),
              ),

              // Mot de passe
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: hasPassword
                    ? t.t('profile_screen.security')
                    : t.t('settings.set_password'),
                subtitle: hasPassword
                    ? t.t('profile_screen.security_sub')
                    : t.t('settings.set_password_sub'),
                cs: cs,
                onTap: () async {
                  if (hasPassword) {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => const ChangePasswordDialog(),
                    );
                    if (changed == true && context.mounted) {
                      AppSnackbar.success(context, t.t('settings.password_changed'));
                    }
                  } else {
                    final set = await showDialog<bool>(
                      context: context,
                      builder: (_) => const SetPasswordDialog(),
                    );
                    if (set == true && context.mounted) {
                      ref.read(userProvider.notifier).refresh();
                      AppSnackbar.success(context, t.t('settings.password_set_success'));
                    }
                  }
                },
              ),

              // Changer email (uniquement si l'utilisateur a un mot de passe)
              if (hasPassword)
                _MenuItem(
                  icon: Icons.alternate_email_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: t.t('settings.change_email'),
                  subtitle: email,
                  cs: cs,
                  onTap: () async {
                    final newEmail = await showDialog<String>(
                      context: context,
                      builder: (_) => ChangeEmailDialog(currentEmail: email),
                    );
                    if (newEmail != null && context.mounted) {
                      ref.read(userProvider.notifier).updateEmail(newEmail);
                      AppSnackbar.success(context, t.t('settings.email_changed'));
                    }
                  },
                ),
              SizedBox(height: 16.h),

              // Supprimer le compte
              _DeleteAccountButton(cs: cs, t: t),
            ],
          ),
        ],
      ),
    );
  }

  void _showPhotoPickerDialog(BuildContext context, WidgetRef ref, ColorScheme cs, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Text(t.t('profile_screen.change_photo'),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () { Navigator.pop(ctx); _pickAndUpload(context, ref, t, ImageSource.camera); },
                  icon: Icon(Icons.camera_rounded, size: 20.sp),
                  label: Text(t.t('profile_screen.take_photo')),
                  style: FilledButton.styleFrom(minimumSize: Size(0, 48.h)),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _pickAndUpload(context, ref, t, ImageSource.gallery); },
                  icon: Icon(Icons.photo_library_rounded, size: 20.sp),
                  label: Text(t.t('profile_screen.choose_photo')),
                  style: OutlinedButton.styleFrom(minimumSize: Size(0, 48.h)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref, AppLocalizations t, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (image == null || !context.mounted) return;

    try {
      final result = await UserService().uploadAvatar(image.path);
      if (!context.mounted) return;
      final avatarUrl = result['avatar_url'] as String?;
      if (avatarUrl != null) {
        ref.read(userProvider.notifier).updateAvatar(avatarUrl);
      }
      AppSnackbar.success(context, t.t('profile_screen.photo_updated'));
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.error(context, t.t('profile_screen.photo_error'));
    }
  }
}

// ─── Widgets privés ──────────────────────────────────────────

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
            Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: cs.primary)),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
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
                  width: 40.w, height: 40.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 20.sp, color: iconColor),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      SizedBox(height: 2.h),
                      Text(subtitle, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
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

/// Bouton destructif avec contour rouge (moins agressif qu'un fond rouge).
class _DeleteAccountButton extends ConsumerWidget {
  final ColorScheme cs;
  final AppLocalizations t;
  const _DeleteAccountButton({required this.cs, required this.t});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever_rounded, size: 40.sp, color: cs.error),
              SizedBox(height: 12.h),
              Text(t.t('settings.delete_account'),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 12.h),
              Text(t.t('settings.delete_account_warning'),
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              SizedBox(height: 14.h),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: t.t('settings.delete_account_email_hint'),
                  prefixIcon: Icon(Icons.email_outlined, size: 20.sp),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(minimumSize: Size(0, 46.h)),
                      child: Text(t.t('settings.cancel')),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        minimumSize: Size(0, 46.h),
                      ),
                      child: Text(t.t('settings.delete_account_confirm')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == null || confirmed.isEmpty || !context.mounted) return;

    try {
      debugPrint('[DELETE] Starting account deletion...');
      await UserService().deleteAccount(confirmed);
      debugPrint('[DELETE] Account deleted on server');
      if (!context.mounted) { debugPrint('[DELETE] Context not mounted after delete!'); return; }
      await AuthStorage().clearTokens();
      debugPrint('[DELETE] Tokens cleared');
      if (!context.mounted) { debugPrint('[DELETE] Context not mounted after clearTokens!'); return; }
      invalidateUserProviders(ref);
      debugPrint('[DELETE] Providers invalidated');
      AppSnackbar.success(context, t.t('settings.delete_account_success'));
      GoRouter.of(context).go('/first-page');
      debugPrint('[DELETE] Navigated to /first-page');
    } catch (e) {
      debugPrint('[DELETE] Error: $e');
      if (!context.mounted) return;
      AppSnackbar.error(context, t.t('settings.delete_account_error'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(30.r),
        onTap: () { Haptic.heavy(); _confirmDelete(context, ref); },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: cs.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever_rounded, size: 20.sp, color: cs.error),
              SizedBox(width: 8.w),
              Text(t.t('settings.delete_account'),
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.error)),
            ],
          ),
        ),
      ),
    );
  }
}
