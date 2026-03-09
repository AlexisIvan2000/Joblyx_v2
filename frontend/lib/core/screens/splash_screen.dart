import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/authentication/presentation/providers/auth_state_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (_, next) {
      if (_navigated) return;
      next.whenData((state) {
        _navigated = true;
        switch (state) {
          case AppAuthState.unauthenticated:
            context.go('/first-page');
          case AppAuthState.needsOnboarding:
            context.go('/onboarding');
          case AppAuthState.authenticated:
            context.go('/dashboard');
          case AppAuthState.loading:
            break;
        }
      });
    });

    // Si le provider a déjà résolu au premier build
    authState.whenData((state) {
      if (_navigated) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_navigated || !mounted) return;
        _navigated = true;
        switch (state) {
          case AppAuthState.unauthenticated:
            context.go('/first-page');
          case AppAuthState.needsOnboarding:
            context.go('/onboarding');
          case AppAuthState.authenticated:
            context.go('/dashboard');
          case AppAuthState.loading:
            break;
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/joblyx_logo.png',
              width: 150.w,
              height: 150.h,
            ),
          ],
        ),
      ),
    );
  }
}
