import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/authentication/presentation/providers/auth_state_provider.dart';

/// Simule les réponses de FlutterSecureStorage via le MethodChannel.
///
/// [tokenValue] est la valeur retournée pour la clé 'access_token'.
/// Si null, hasTokens() retournera false.
void _mockSecureStorage({String? tokenValue}) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'read') {
      final key = methodCall.arguments['key'] as String?;
      if (key == 'access_token') return tokenValue;
      return null;
    }
    if (methodCall.method == 'write' || methodCall.method == 'delete') {
      return null;
    }
    return null;
  });
}

/// Supprime le mock du MethodChannel.
void _clearSecureStorageMock() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearSecureStorageMock);

  group('AuthStateNotifier', () {
    test('retourne authenticated quand des tokens existent', () async {
      _mockSecureStorage(tokenValue: 'fake-access-token');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);
      expect(result, AppAuthState.authenticated);
    });

    test('retourne unauthenticated quand aucun token', () async {
      _mockSecureStorage(tokenValue: null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(authStateProvider.future);
      expect(result, AppAuthState.unauthenticated);
    });

    test('recheck passe de unauthenticated à authenticated', () async {
      // Démarrer sans token
      _mockSecureStorage(tokenValue: null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(authStateProvider.future);
      expect(initial, AppAuthState.unauthenticated);

      // Simuler l'ajout d'un token
      _mockSecureStorage(tokenValue: 'new-token');

      await container.read(authStateProvider.notifier).recheck();

      final updated = await container.read(authStateProvider.future);
      expect(updated, AppAuthState.authenticated);
    });

    test('recheck passe de authenticated à unauthenticated', () async {
      // Démarrer avec un token
      _mockSecureStorage(tokenValue: 'existing-token');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(authStateProvider.future);
      expect(initial, AppAuthState.authenticated);

      // Simuler la suppression du token
      _mockSecureStorage(tokenValue: null);

      await container.read(authStateProvider.notifier).recheck();

      final updated = await container.read(authStateProvider.future);
      expect(updated, AppAuthState.unauthenticated);
    });
  });

  group('AppAuthState enum', () {
    test('contient les trois valeurs attendues', () {
      expect(AppAuthState.values, containsAll([
        AppAuthState.loading,
        AppAuthState.unauthenticated,
        AppAuthState.authenticated,
      ]));
      expect(AppAuthState.values.length, 3);
    });
  });
}
