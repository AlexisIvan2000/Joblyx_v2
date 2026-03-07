import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/routes.dart';
import 'package:frontend/core/screens/first_page.dart';
import 'package:frontend/core/screens/loading_transition.dart';
import 'package:frontend/features/authentication/presentation/screens/login_screen.dart';
import 'package:frontend/features/authentication/presentation/screens/register_screen.dart';
import 'package:frontend/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/roadmap_screen.dart';
import 'package:frontend/features/settings/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.loading,
  routes: [
    _slideRoute(AppRoutes.firstPage, (_) => const FirstPage()),
    _slideRoute(AppRoutes.login, (_) => const LoginScreen()),
    _slideRoute(AppRoutes.register, (_) => const RegisterScreen()),
    _slideRoute(AppRoutes.loading, (_) => const LoadingTransition()),
    _slideRoute(AppRoutes.onboarding, (_) => const OnboardingScreen()),
    _slideRoute(AppRoutes.dashboard, (_) => const RoadmapScreen()),
    _slideRoute(AppRoutes.settings, (_) => const SettingsScreen()),
  ],
);

GoRoute _slideRoute(String path, Widget Function(GoRouterState) builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: builder(state),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ));

        final secondaryOffset = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOut,
        ));

        return SlideTransition(
          position: secondaryOffset,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
}
