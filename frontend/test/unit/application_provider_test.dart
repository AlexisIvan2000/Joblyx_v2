import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/applications/data/application_service.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';

final _apps = [
  {
    'id': 'a1',
    'company_name': 'Google',
    'job_title': 'Flutter Dev',
    'status': 'applied',
    'applied_at': '2026-03-20T10:00:00',
    'updated_at': '2026-03-20T10:00:00',
  },
  {
    'id': 'a2',
    'company_name': 'Apple',
    'job_title': 'iOS Dev',
    'status': 'saved',
    'applied_at': '2026-03-19T10:00:00',
    'updated_at': '2026-03-19T10:00:00',
  },
];

({ProviderContainer container, DioAdapter adapter}) _setup({
  List<Map<String, dynamic>>? data,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  final svc = ApplicationService.withDio(dio);

  // Mock GET /applications (appelé par build + refresh)
  adapter.onGet('/applications', (server) {
    server.reply(200, data ?? _apps);
  });

  final container = ProviderContainer(
    overrides: [applicationServiceProvider.overrideWithValue(svc)],
  );
  return (container: container, adapter: adapter);
}

void main() {
  group('ApplicationsNotifier', () {
    test('build charge la liste des candidatures', () async {
      final (:container, :adapter) = _setup();

      final apps = await container.read(applicationsProvider.future);
      expect(apps.length, 2);
      expect(apps[0]['company_name'], 'Google');
      expect(apps[1]['company_name'], 'Apple');
      container.dispose();
    });

    test('build retourne une liste vide si aucune candidature', () async {
      final (:container, :adapter) = _setup(data: []);

      final apps = await container.read(applicationsProvider.future);
      expect(apps, isEmpty);
      container.dispose();
    });

    test('refresh recharge depuis le serveur', () async {
      final (:container, :adapter) = _setup();

      // Charger initialement
      await container.read(applicationsProvider.future);

      // Refresh
      await container.read(applicationsProvider.notifier).refresh();
      final apps = await container.read(applicationsProvider.future);
      expect(apps.length, 2);
      container.dispose();
    });

    test('create appelle le service puis refresh', () async {
      final (:container, :adapter) = _setup();
      await container.read(applicationsProvider.future);

      // Mock le POST
      adapter.onPost('/applications', (server) {
        server.reply(201, {
          'id': 'a3',
          'company_name': 'Meta',
          'job_title': 'React Dev',
          'status': 'saved',
        });
      }, data: Matchers.any);

      await container.read(applicationsProvider.notifier).create({
        'company_name': 'Meta',
        'job_title': 'React Dev',
        'status': 'saved',
      });

      // Après refresh, la liste est rechargée (toujours 2 car le mock GET retourne _apps)
      final apps = await container.read(applicationsProvider.future);
      expect(apps.length, 2);
      container.dispose();
    });

    test('updateApplication appelle le service puis refresh', () async {
      final (:container, :adapter) = _setup();
      await container.read(applicationsProvider.future);

      adapter.onPut('/applications/a1', (server) {
        server.reply(200, {..._apps[0], 'status': 'offer'});
      }, data: Matchers.any);

      await container.read(applicationsProvider.notifier).updateApplication(
        'a1',
        {'status': 'offer'},
      );

      final apps = await container.read(applicationsProvider.future);
      expect(apps, isNotEmpty);
      container.dispose();
    });

    test('delete appelle le service puis refresh', () async {
      final (:container, :adapter) = _setup();
      await container.read(applicationsProvider.future);

      adapter.onDelete('/applications/a1', (server) {
        server.reply(200, {'message': 'Deleted'});
      });

      await container.read(applicationsProvider.notifier).delete('a1');

      final apps = await container.read(applicationsProvider.future);
      expect(apps, isNotEmpty);
      container.dispose();
    });
  });
}
