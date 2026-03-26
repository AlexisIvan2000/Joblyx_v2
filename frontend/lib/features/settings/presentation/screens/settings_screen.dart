import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/presentation/providers/preferences_provider.dart';
import 'package:frontend/features/settings/presentation/utils/invalidate_providers.dart';
import 'package:frontend/core/widgets/staggered_list.dart';

const _termsUrl = 'https://joblyx.com/conditions-utilisation';
const _privacyUrl = 'https://joblyx.com/politiques-confidentialit%C3%A9';
const _linkedinUrl = 'https://www.linkedin.com/company/joblyx/';
const _supportEmail = 'support@joblyx.com';
const _appVersion = '0.1.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings.title'))),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        child: StaggeredList(
          children: [
          // ── Général ──────────────────────────────────────────
          _SectionTitle(label: t.t('settings.section_general')),
          SizedBox(height: 6.h),

          // Langue
          _MenuItem(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF2563EB),
            title: t.t('settings.language'),
            subtitle: _localeName(prefs.localeCode, t),
            cs: cs,
            onTap: () => _showLanguagePicker(context, ref, t, cs, prefs.localeCode),
          ),

          // Thème
          _MenuItem(
            icon: Icons.palette_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: t.t('settings.theme'),
            subtitle: _themeName(prefs.themeMode, t),
            cs: cs,
            onTap: () => _showThemePicker(context, ref, t, cs, prefs.themeMode),
          ),

          SizedBox(height: 20.h),

          // ── Légal ────────────────────────────────────────────
          _SectionTitle(label: t.t('settings.section_legal')),
          SizedBox(height: 6.h),

          _MenuItem(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF059669),
            title: t.t('settings.terms'),
            subtitle: 'joblyx.com',
            cs: cs,
            onTap: () => launchUrl(Uri.parse(_termsUrl), mode: LaunchMode.externalApplication),
          ),

          _MenuItem(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF0891B2),
            title: t.t('settings.privacy'),
            subtitle: 'joblyx.com',
            cs: cs,
            onTap: () => launchUrl(Uri.parse(_privacyUrl), mode: LaunchMode.externalApplication),
          ),

          SizedBox(height: 20.h),

          // ── Nous contacter ─────────────────────────────────────
          _SectionTitle(label: t.t('settings.section_contact')),
          SizedBox(height: 6.h),

          _MenuItem(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFD97706),
            title: t.t('settings.contact_email'),
            subtitle: _supportEmail,
            cs: cs,
            onTap: () => launchUrl(
              Uri(scheme: 'mailto', path: _supportEmail,
                  queryParameters: {'subject': 'Bug/Suggestion'}),
            ),
          ),

          _MenuItem(
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF0A66C2),
            title: 'LinkedIn',
            subtitle: 'Joblyx',
            cs: cs,
            onTap: () => launchUrl(Uri.parse(_linkedinUrl), mode: LaunchMode.externalApplication),
          ),

          SizedBox(height: 20.h),

          // ── Supprimer le compte ──────────────────────────────
          _DeleteAccountButton(cs: cs, t: t),

          SizedBox(height: 24.h),

          // Version
          Center(
            child: Text(
              '${t.t('settings.app_version')} $_appVersion',
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ── Helpers pour les labels ─────────────────────────────────

  String _localeName(String? code, AppLocalizations t) => switch (code) {
        'fr' => t.t('settings.language_fr'),
        'en' => t.t('settings.language_en'),
        _ => t.t('settings.language_system'),
      };

  String _themeName(ThemeMode mode, AppLocalizations t) => switch (mode) {
        ThemeMode.light => t.t('settings.theme_light'),
        ThemeMode.dark => t.t('settings.theme_dark'),
        _ => t.t('settings.theme_system'),
      };

  // ── Pickers ─────────────────────────────────────────────────

  void _showLanguagePicker(BuildContext context, WidgetRef ref, AppLocalizations t, ColorScheme cs, String? current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 16.h),
            Text(t.t('settings.language'), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 12.h),
            _RadioOption(
              label: t.t('settings.language_system'),
              selected: current == null,
              onTap: () { ref.read(preferencesProvider.notifier).setLocale(null); Navigator.pop(ctx); },
              cs: cs,
            ),
            _RadioOption(
              label: t.t('settings.language_fr'),
              selected: current == 'fr',
              onTap: () { ref.read(preferencesProvider.notifier).setLocale('fr'); Navigator.pop(ctx); },
              cs: cs,
            ),
            _RadioOption(
              label: t.t('settings.language_en'),
              selected: current == 'en',
              onTap: () { ref.read(preferencesProvider.notifier).setLocale('en'); Navigator.pop(ctx); },
              cs: cs,
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, AppLocalizations t, ColorScheme cs, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 16.h),
            Text(t.t('settings.theme'), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 12.h),
            _RadioOption(
              label: t.t('settings.theme_system'),
              icon: Icons.phone_android_rounded,
              selected: current == ThemeMode.system,
              onTap: () { ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.system); Navigator.pop(ctx); },
              cs: cs,
            ),
            _RadioOption(
              label: t.t('settings.theme_light'),
              icon: Icons.light_mode_rounded,
              selected: current == ThemeMode.light,
              onTap: () { ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.light); Navigator.pop(ctx); },
              cs: cs,
            ),
            _RadioOption(
              label: t.t('settings.theme_dark'),
              icon: Icons.dark_mode_rounded,
              selected: current == ThemeMode.dark,
              onTap: () { ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.dark); Navigator.pop(ctx); },
              cs: cs,
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets privés ──────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
      child: Text(label.toUpperCase(),
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.2)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title, subtitle;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, this.iconColor, required this.title, required this.subtitle, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? cs.primary;
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 20.sp, color: color),
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

class _RadioOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _RadioOption({required this.label, this.icon, required this.selected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant, size: 22.sp) : null,
      title: Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : cs.onSurface)),
      trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? cs.primary : cs.onSurfaceVariant, size: 22.sp),
      onTap: onTap,
    );
  }
}

class _DeleteAccountButton extends ConsumerWidget {
  final ColorScheme cs;
  final AppLocalizations t;
  const _DeleteAccountButton({required this.cs, required this.t});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final confirmed = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8.h),
                Container(width: 40.w, height: 4.h,
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2.r))),
                SizedBox(height: 16.h),
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
                        child: Text(t.t('settings.cancel')),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
                        style: FilledButton.styleFrom(backgroundColor: cs.error),
                        child: Text(t.t('settings.delete_account_confirm')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == null || confirmed.isEmpty || !context.mounted) return;

    try {
      await UserService().deleteAccount(confirmed);
      if (!context.mounted) return;
      await AuthStorage().clearTokens();
      if (!context.mounted) return;
      invalidateUserProviders(ref);
      AppSnackbar.success(context, t.t('settings.delete_account_success'));
      GoRouter.of(context).go('/first-page');
    } catch (_) {
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
        onTap: () => _confirmDelete(context, ref),
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
