import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/authentication/presentation/providers/auth_state_provider.dart';

/// Page de transition animée.
/// Utilisée après login/register → vérifie le provider et redirige.
class LoadingTransition extends ConsumerStatefulWidget {
  const LoadingTransition({super.key});

  @override
  ConsumerState<LoadingTransition> createState() => _LoadingTransitionState();
}

class _LoadingTransitionState extends ConsumerState<LoadingTransition> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authStateProvider.notifier).recheck());
  }

  void _navigate(AppAuthState state) {
    if (_navigated || !mounted) return;
    _navigated = true;
    switch (state) {
      case AppAuthState.unauthenticated:
        context.go('/first-page');
      case AppAuthState.authenticated:
        context.go('/dashboard');
      case AppAuthState.loading:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    ref.listen(authStateProvider, (_, next) {
      next.whenData(_navigate);
    });

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
              SizedBox(height: 24.h),
              SizedBox(
                width: 180.w,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
