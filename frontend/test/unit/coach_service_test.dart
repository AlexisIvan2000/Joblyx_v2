import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/assistant/data/coach_service.dart';

({CoachService svc, DioAdapter adapter}) _setup() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  return (svc: CoachService.withDio(dio), adapter: adapter);
}

void main() {
  group('CoachService', () {
    test('getHistory retourne la liste des sessions', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/coach/history', (server) {
        server.reply(200, [
          {
            'id': 's1',
            'job_title': 'Dev Flutter',
            'company_name': 'Google',
            'compatibility_score': 72,
            'created_at': '2026-03-20T10:00:00',
          },
        ]);
      });

      final result = await svc.getHistory();
      expect(result.length, 1);
      expect(result[0]['compatibility_score'], 72);
    });

    test('getHistory retourne une liste vide', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/coach/history', (server) {
        server.reply(200, []);
      });

      final result = await svc.getHistory();
      expect(result, isEmpty);
    });

    test('getSession retourne le détail complet', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/coach/s1', (server) {
        server.reply(200, {
          'id': 's1',
          'job_title': 'Dev',
          'analysis': {'compatibility_score': 80},
          'created_at': '2026-03-20T10:00:00',
        });
      });

      final result = await svc.getSession('s1');
      expect(result['id'], 's1');
      expect((result['analysis'] as Map)['compatibility_score'], 80);
    });

    test('getSession 404 throw', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/coach/notfound', (server) {
        server.reply(404, {'detail': 'Not found'});
      });

      expect(() => svc.getSession('notfound'), throwsA(isA<DioException>()));
    });

    test('deleteSession appelle DELETE', () async {
      final (:svc, :adapter) = _setup();
      adapter.onDelete('/assistant/coach/s1', (server) {
        server.reply(200, {'message': 'Deleted'});
      });

      await svc.deleteSession('s1');
    });

    test('deleteAll retourne le count', () async {
      final (:svc, :adapter) = _setup();
      adapter.onDelete('/assistant/coach', (server) {
        server.reply(200, {'message': '2 deleted', 'count': 2});
      });

      final count = await svc.deleteAll();
      expect(count, 2);
    });

    test('getUsage retourne les compteurs', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/coach/usage', (server) {
        server.reply(200, {
          'used': 1,
          'limit': 3,
          'remaining': 2,
          'resets_at': '2026-03-24T00:00:00Z',
        });
      });

      final result = await svc.getUsage();
      expect(result['remaining'], 2);
      expect(result['limit'], 3);
    });

    test('constructeur withDio fonctionne', () {
      final (:svc, :adapter) = _setup();
      expect(svc, isA<CoachService>());
    });
  });
}
