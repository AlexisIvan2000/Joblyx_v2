import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/router/routes.dart';
import 'package:frontend/core/screens/first_page.dart';
import 'package:frontend/core/screens/loading_transition.dart';
import 'package:frontend/core/screens/main_shell.dart';
import 'package:frontend/core/screens/splash_screen.dart';
import 'package:frontend/features/authentication/presentation/screens/login_screen.dart';
import 'package:frontend/features/authentication/presentation/screens/register_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/dashboard_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/roadmap_screen.dart';
import 'package:frontend/features/applications/presentation/screens/applications_screen.dart';
import 'package:frontend/features/applications/presentation/screens/application_detail_screen.dart';
import 'package:frontend/features/settings/presentation/screens/profile_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/ai_roadmap_form_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/create_roadmap_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/roadmap_detail_screen.dart';
import 'package:frontend/features/roadmap/presentation/screens/roadmap_history_screen.dart';
import 'package:frontend/features/settings/presentation/screens/settings_screen.dart';

final _shellKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    // Splash — point d'entrée, écoute les providers
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SplashScreen(),
      ),
    ),

    // Ecrans hors bottom nav
    _slideRoute(AppRoutes.firstPage, (_) => const FirstPage()),
    _slideRoute(AppRoutes.login, (_) => const LoginScreen()),
    _slideRoute(AppRoutes.register, (_) => const RegisterScreen()),
    _slideRoute(AppRoutes.loading, (_) => const LoadingTransition()),
    _slideRoute(AppRoutes.settings, (_) => const SettingsScreen()),
    _slideRoute(AppRoutes.generateAI, (_) => const AIRoadmapFormScreen()),
    _slideRoute(AppRoutes.createRoadmap, (_) => const CreateRoadmapScreen()),
    _slideRoute(AppRoutes.roadmapHistory, (_) => const RoadmapHistoryScreen()),
    _slideRoute(AppRoutes.roadmapDetail, (state) =>
        RoadmapDetailScreen(roadmapId: state.pathParameters['id']!)),
    _slideRoute(AppRoutes.applicationDetail, (state) =>
        ApplicationDetailScreen(applicationId: state.pathParameters['id']!)),

    // Shell avec bottom navigation
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) {
        final index = _tabIndex(state.uri.path);
        return MainShell(currentIndex: index, child: child);
      },
      routes: [
        _noTransitionRoute(AppRoutes.dashboard, (_) => const DashboardScreen()),
        _noTransitionRoute(AppRoutes.roadmap, (_) => const RoadmapScreen()),
        _noTransitionRoute(AppRoutes.applications, (_) => const ApplicationsScreen()),
        _noTransitionRoute(AppRoutes.profile, (_) => const ProfileScreen()),
      ],
    ),
  ],
);

int _tabIndex(String path) {
  if (path.startsWith('/roadmap')) return 1;
  if (path.startsWith('/applications')) return 2;
  if (path.startsWith('/profile')) return 3;
  return 0; // dashboard
}

/// Route avec transition slide (pour les écrans hors shell)
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
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final secondaryOffset = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.15, 0.0),
        ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic));

        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5)));

        return SlideTransition(
          position: secondaryOffset,
          child: SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

/// Route sans transition (pour les onglets du shell)
GoRoute _noTransitionRoute(String path, Widget Function(GoRouterState) builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: builder(state),
    ),
  );
}
