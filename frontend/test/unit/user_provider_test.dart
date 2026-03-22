import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/settings/data/user_service.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';

/// Crée un container avec un UserService mocké.
({ProviderContainer container, DioAdapter adapter}) _setup({
  Map<String, dynamic>? userData,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  final svc = UserService.withDio(dio);

  // Mock GET /users/me (appelé par build)
  adapter.onGet('/users/me', (server) {
    server.reply(200, userData ?? {
      'id': 'u1',
      'first_name': 'Alexis',
      'last_name': 'Moungang',
      'email': 'alexis@test.com',
      'is_verified': true,
      'avatar_url': null,
      'pending_email': null,
    });
  });

  final container = ProviderContainer(
    overrides: [userServiceProvider.overrideWithValue(svc)],
  );
  return (container: container, adapter: adapter);
}

void main() {
  group('UserNotifier', () {
    test('build charge les données utilisateur', () async {
      final (:container, :adapter) = _setup();

      final user = await container.read(userProvider.future);
      expect(user['first_name'], 'Alexis');
      expect(user['email'], 'alexis@test.com');
      container.dispose();
    });

    test('updateName met à jour le state sans appel réseau', () async {
      final (:container, :adapter) = _setup();

      // Attendre le chargement initial
      await container.read(userProvider.future);

      // Update optimiste
      container.read(userProvider.notifier).updateName(
        firstName: 'Jean',
        lastName: 'Dupont',
      );

      final user = await container.read(userProvider.future);
      expect(user['first_name'], 'Jean');
      expect(user['last_name'], 'Dupont');
      // L'email n'a pas changé
      expect(user['email'], 'alexis@test.com');
      container.dispose();
    });

    test('updateEmail met à jour le state sans appel réseau', () async {
      final (:container, :adapter) = _setup();
      await container.read(userProvider.future);

      container.read(userProvider.notifier).updateEmail('new@test.com');

      final user = await container.read(userProvider.future);
      expect(user['email'], 'new@test.com');
      expect(user['pending_email'], isNull);
      container.dispose();
    });

    test('updateAvatar met à jour le state sans appel réseau', () async {
      final (:container, :adapter) = _setup();
      await container.read(userProvider.future);

      container.read(userProvider.notifier).updateAvatar('https://new-avatar-url.com');

      final user = await container.read(userProvider.future);
      expect(user['avatar_url'], 'https://new-avatar-url.com');
      container.dispose();
    });

    test('refresh recharge depuis le serveur', () async {
      final (:container, :adapter) = _setup();
      await container.read(userProvider.future);

      // Modifier localement
      container.read(userProvider.notifier).updateName(firstName: 'Local', lastName: 'Change');

      // Refresh recharge depuis le mock (qui retourne Alexis)
      await container.read(userProvider.notifier).refresh();

      final user = await container.read(userProvider.future);
      expect(user['first_name'], 'Alexis');
      container.dispose();
    });

    test('updateName ne fait rien si state non chargé', () {
      final (:container, :adapter) = _setup();

      // Avant le chargement initial, updateName ne doit pas crasher
      container.read(userProvider.notifier).updateName(firstName: 'X', lastName: 'Y');
      container.dispose();
    });
  });
}
