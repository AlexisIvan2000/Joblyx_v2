import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';

enum AppAuthState {
  loading,
  unauthenticated,
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
    return hasTokens ? AppAuthState.authenticated : AppAuthState.unauthenticated;
  }

  /// Relancer la vérification (après login, register, logout, etc.)
  Future<void> recheck() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
