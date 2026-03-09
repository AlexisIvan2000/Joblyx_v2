import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/features/onboarding/data/onboarding_service.dart';

enum AppAuthState {
  loading,
  unauthenticated,
  needsOnboarding,
  authenticated,
}

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, AppAuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends AsyncNotifier<AppAuthState> {
  @override
  Future<AppAuthState> build() async {
    final storage = AuthStorage();
    final hasTokens = await storage.hasTokens();

    if (!hasTokens) return AppAuthState.unauthenticated;

    try {
      final hasProfile = await OnboardingService().checkStatus();
      return hasProfile ? AppAuthState.authenticated : AppAuthState.needsOnboarding;
    } catch (_) {
      // Token invalide ou erreur réseau — vérifier si on a encore des tokens
      final stillHasTokens = await storage.hasTokens();
      return stillHasTokens ? AppAuthState.authenticated : AppAuthState.unauthenticated;
    }
  }

  /// Relancer la vérification (après login, register, logout, etc.)
  Future<void> recheck() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
