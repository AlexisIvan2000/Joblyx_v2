import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';

/// Creates a [RoadmapService] backed by a mock [Dio] + [DioAdapter].
({RoadmapService svc, DioAdapter adapter}) _createMockService() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  final svc = RoadmapService.withDio(dio);
  return (svc: svc, adapter: adapter);
}

void main() {
  group('RoadmapService', () {
    // getStatus 
    test('getStatus returns status map', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/status', (server) {
        server.reply(200, {'generation_status': 'idle', 'has_roadmap': false});
      });

      final result = await svc.getStatus();
      expect(result['generation_status'], 'idle');
      expect(result['has_roadmap'], false);
    });

    // getRoadmap
    test('getRoadmap returns roadmap data', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap', (server) {
        server.reply(200, {
          'id': '123',
          'summary': {},
          'phases': [],
          'status': 'active',
        });
      });

      final result = await svc.getRoadmap();
      expect(result['id'], '123');
      expect(result['phases'], isEmpty);
    });

    // 
    //getCareerProfile 
    test('getCareerProfile returns career data', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/career', (server) {
        server.reply(200, {
          'level': 'junior',
          'years_experience': 2,
          'target_jobs': ['Developer'],
          'city': 'Montreal',
          'province': 'QC',
          'language': 'fr',
          'previous_field': null,
          'skills': [
            {'skill_name': 'Python', 'category': 'Backend', 'proficiency': 'intermediate'},
          ],
        });
      });

      final result = await svc.getCareerProfile();
      expect(result['level'], 'junior');
      expect(result['city'], 'Montreal');
      expect((result['skills'] as List).length, 1);
    });

    test('getCareerProfile throws on 404 (no career)', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/career', (server) {
        server.reply(404, {'detail': 'Career profile not found'});
      });

      expect(() => svc.getCareerProfile(), throwsA(isA<DioException>()));
    });

    // updateCareerProfile 
    test('updateCareerProfile sends data and returns updated profile', () async {
      final (:svc, :adapter) = _createMockService();
      final updateData = {
        'level': 'mid',
        'city': 'Toronto',
        'province': 'ON',
        'skills': [
          {'skill_name': 'Dart', 'category': 'Frontend', 'proficiency': 'advanced'},
        ],
      };

      adapter.onPut('/roadmap/career', (server) {
        server.reply(200, {
          'level': 'mid',
          'years_experience': 2,
          'target_jobs': ['Developer'],
          'city': 'Toronto',
          'province': 'ON',
          'language': 'fr',
          'previous_field': null,
          'skills': [
            {'skill_name': 'Dart', 'category': 'Frontend', 'proficiency': 'advanced'},
          ],
        });
      }, data: updateData);

      final result = await svc.updateCareerProfile(updateData);
      expect(result['level'], 'mid');
      expect(result['city'], 'Toronto');
    });

    // getRegenerationStatus 
    test('getRegenerationStatus returns correct counts', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/regeneration-status', (server) {
        server.reply(200, {
          'used': 1,
          'limit': 5,
          'remaining': 4,
          'resets_at': '2026-04-01T00:00:00+00:00',
        });
      });

      final result = await svc.getRegenerationStatus();
      expect(result['remaining'], 4);
      expect(result['limit'], 5);
    });

    test('getRegenerationStatus for new user shows full limit', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/regeneration-status', (server) {
        server.reply(200, {
          'used': 0,
          'limit': 5,
          'remaining': 5,
          'resets_at': '2026-04-01T00:00:00+00:00',
        });
      });

      final result = await svc.getRegenerationStatus();
      expect(result['remaining'], 5);
      expect(result['used'], 0);
    });

    // createManual 
    test('createManual sends phases and returns roadmap', () async {
      final (:svc, :adapter) = _createMockService();
      final phases = [
        {'title': 'Phase 1', 'duration_weeks': 4, 'objective': 'Learn basics'},
      ];

      adapter.onPost('/roadmap/manual', (server) {
        server.reply(200, {
          'id': 'abc',
          'summary': null,
          'phases': phases,
          'status': 'active',
        });
      }, data: {'phases': phases});

      final result = await svc.createManual(phases);
      expect(result['id'], 'abc');
    });

    // Phase operations 
    test('togglePhaseComplete returns updated phase', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onPatch('/roadmap/phases/p1/complete', (server) {
        server.reply(200, {'id': 'p1', 'completed': true});
      });

      final result = await svc.togglePhaseComplete('p1');
      expect(result['completed'], true);
    });

    test('toggleActionComplete returns updated phase', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onPatch('/roadmap/phases/p1/actions/0/complete', (server) {
        server.reply(200, {'id': 'p1', 'actions': [{'completed': true}]});
      });

      final result = await svc.toggleActionComplete('p1', 0);
      expect((result['actions'] as List).first['completed'], true);
    });

    test('deletePhase sends delete request', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onDelete('/roadmap/phases/p1', (server) {
        server.reply(204, null);
      });

      // Should not throw
      await svc.deletePhase('p1');
    });

    //  History 
    test('getHistory returns list of roadmaps', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onGet('/roadmap/history', (server) {
        server.reply(200, [
          {'id': 'r1', 'status': 'archived'},
          {'id': 'r2', 'status': 'archived'},
        ]);
      });

      final result = await svc.getHistory();
      expect(result.length, 2);
    });

    test('restoreRoadmap returns restored roadmap', () async {
      final (:svc, :adapter) = _createMockService();
      adapter.onPost('/roadmap/r1/restore', (server) {
        server.reply(200, {'id': 'r1', 'status': 'active', 'phases': []});
      });

      final result = await svc.restoreRoadmap('r1');
      expect(result['status'], 'active');
    });
  });
}
