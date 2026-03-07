import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/features/onboarding/data/onboarding_service.dart';

class LoadingTransition extends StatefulWidget {
  const LoadingTransition({super.key});

  @override
  State<LoadingTransition> createState() => _LoadingTransitionState();
}

class _LoadingTransitionState extends State<LoadingTransition> {
  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    final storage = AuthStorage();
    final hasTokens = await storage.hasTokens();

    if (!mounted) return;

    // Pas de token → écran d'accueil
    if (!hasTokens) {
      context.go('/first-page');
      return;
    }

    // Token présent → vérifier le statut onboarding
    try {
      final hasProfile = await OnboardingService().checkStatus();
      if (!mounted) return;
      context.go(hasProfile ? '/dashboard' : '/onboarding');
    } catch (_) {
      if (!mounted) return;
      // Token invalide ou erreur réseau → retour à l'accueil
      final stillHasTokens = await storage.hasTokens();
      if (!mounted) return;
      context.go(stillHasTokens ? '/dashboard' : '/first-page');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/processing.svg',
                width: 280.w,
                height: 280.h,
              ),
              SizedBox(height: 10.h),
              Text(
                t.t('loading.loading'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}