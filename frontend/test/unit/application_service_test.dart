

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/applications/data/application_service.dart';

final _appData = {
  'id': 'a1',
  'company_name': 'Google',
  'job_title': 'Flutter Dev',
  'status': 'applied',
  'job_url': 'https://google.com/jobs/1',
  'job_description': 'A great job',
  'notes': null,
  'cv_file_key': null,
  'applied_at': '2026-03-20T10:00:00',
  'updated_at': '2026-03-20T10:00:00',
};

({ApplicationService svc, DioAdapter adapter}) _setup() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  return (svc: ApplicationService.withDio(dio), adapter: adapter);
}

void main() {
  group('ApplicationService', () {
    test('getAll retourne la liste des candidatures', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/applications', (server) {
        server.reply(200, [_appData]);
      });

      final result = await svc.getAll();
      expect(result, isA<List>());
      expect(result.length, 1);
      expect(result[0]['company_name'], 'Google');
    });

    test('getAll avec filtre status envoie le paramètre', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/applications', (server) {
        server.reply(200, [_appData]);
      }, queryParameters: {'status': 'applied'});

      final result = await svc.getAll(status: 'applied');
      expect(result.length, 1);
    });

    test('getById retourne une candidature', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/applications/a1', (server) {
        server.reply(200, _appData);
      });

      final result = await svc.getById('a1');
      expect(result['id'], 'a1');
      expect(result['job_title'], 'Flutter Dev');
    });

    test('getById avec id inexistant retourne 404', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/applications/notfound', (server) {
        server.reply(404, {'detail': 'Not found'});
      });

      expect(
        () => svc.getById('notfound'),
        throwsA(isA<DioException>()),
      );
    });

    test('create envoie les données en FormData', () async {
      final (:svc, :adapter) = _setup();
      adapter.onPost('/applications', (server) {
        server.reply(201, _appData);
      }, data: Matchers.any);

      final result = await svc.create({
        'company_name': 'Google',
        'job_title': 'Flutter Dev',
        'status': 'applied',
      });
      expect(result['company_name'], 'Google');
    });

    test('update envoie les données en FormData', () async {
      final (:svc, :adapter) = _setup();
      adapter.onPut('/applications/a1', (server) {
        server.reply(200, {..._appData, 'status': 'offer'});
      }, data: Matchers.any);

      final result = await svc.update('a1', {'status': 'offer'});
      expect(result['status'], 'offer');
    });

    test('delete appelle DELETE /applications/{id}', () async {
      final (:svc, :adapter) = _setup();
      adapter.onDelete('/applications/a1', (server) {
        server.reply(200, {'message': 'Deleted'});
      });

      // Ne doit pas throw
      await svc.delete('a1');
    });

    test('le constructeur withDio fonctionne', () {
      final (:svc, :adapter) = _setup();
      expect(svc, isA<ApplicationService>());
    });
  });
}
