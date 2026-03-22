import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/assistant/data/interview_service.dart';

({InterviewService svc, DioAdapter adapter}) _setup() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  return (svc: InterviewService.withDio(dio), adapter: adapter);
}

void main() {
  group('InterviewService', () {
    test('startSession retourne session_id et first_question', () async {
      final (:svc, :adapter) = _setup();
      adapter.onPost('/assistant/interview/start', (server) {
        server.reply(200, {
          'session_id': 's1',
          'first_question': {
            'message': 'Parlez-moi de vous',
            'question_type': 'introduction',
            'question_number': 1,
          },
        });
      }, data: Matchers.any);

      final result = await svc.startSession(jobTitle: 'Dev');
      expect(result['session_id'], 's1');
      expect(result['first_question']['question_number'], 1);
    });

    test('getHistory retourne la liste', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/interview/history', (server) {
        server.reply(200, [
          {'id': 's1', 'job_title': 'Dev', 'status': 'completed', 'overall_score': 75},
        ]);
      });

      final result = await svc.getHistory();
      expect(result.length, 1);
      expect(result[0]['overall_score'], 75);
    });

    test('getHistory retourne liste vide', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/interview/history', (server) {
        server.reply(200, []);
      });

      final result = await svc.getHistory();
      expect(result, isEmpty);
    });

    test('getSession retourne le détail avec messages', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/interview/s1', (server) {
        server.reply(200, {
          'id': 's1',
          'status': 'completed',
          'messages': [
            {'role': 'assistant', 'content': 'Bonjour', 'position': 1},
          ],
        });
      });

      final result = await svc.getSession('s1');
      expect(result['id'], 's1');
      expect((result['messages'] as List).length, 1);
    });

    test('getUsage retourne les compteurs', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/interview/usage', (server) {
        server.reply(200, {'used': 0, 'limit': 1, 'remaining': 1, 'resets_at': '2026-03-23T00:00:00Z'});
      });

      final result = await svc.getUsage();
      expect(result['remaining'], 1);
      expect(result['limit'], 1);
    });

    test('deleteSession appelle DELETE', () async {
      final (:svc, :adapter) = _setup();
      adapter.onDelete('/assistant/interview/s1', (server) {
        server.reply(200, {'message': 'Deleted'});
      });

      await svc.deleteSession('s1');
    });

    test('deleteAll retourne le count', () async {
      final (:svc, :adapter) = _setup();
      adapter.onDelete('/assistant/interview', (server) {
        server.reply(200, {'message': '2 deleted', 'count': 2});
      });

      final count = await svc.deleteAll();
      expect(count, 2);
    });

    test('endSessionEarly appelle POST', () async {
      final (:svc, :adapter) = _setup();
      adapter.onPost('/assistant/interview/s1/end', (server) {
        server.reply(200, {
          'message': 'Avez-vous des questions ?',
          'feedback': null,
          'is_last': false,
        });
      });

      final result = await svc.endSessionEarly('s1');
      expect(result['is_last'], false);
    });

    test('getSummary retourne le bilan', () async {
      final (:svc, :adapter) = _setup();
      adapter.onGet('/assistant/interview/s1/summary', (server) {
        server.reply(200, {
          'overall_score': 72,
          'category_scores': {'technical': 80},
          'summary': 'Good performance',
        });
      });

      final result = await svc.getSummary('s1');
      expect(result['overall_score'], 72);
    });

    test('constructeur withDio fonctionne', () {
      final (:svc, :adapter) = _setup();
      expect(svc, isA<InterviewService>());
    });
  });
}
