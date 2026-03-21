import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';

({ProviderContainer container, DioAdapter adapter, RoadmapNotifier notifier}) _setup({
  Map<String, dynamic>? statusResponse,
  Map<String, dynamic>? roadmapResponse,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final adapter = DioAdapter(dio: dio);
  final svc = RoadmapService.withDio(dio);

  // Always mock since build() auto-calls loadStatus
  adapter.onGet('/roadmap/status', (server) {
    server.reply(200, statusResponse ?? {'generation_status': 'idle', 'has_roadmap': false});
  });
  if (roadmapResponse != null) {
    adapter.onGet('/roadmap', (server) {
      server.reply(200, roadmapResponse);
    });
  }

  final container = ProviderContainer(
    overrides: [roadmapServiceProvider.overrideWithValue(svc)],
  );
  final notifier = container.read(roadmapProvider.notifier);
  return (container: container, adapter: adapter, notifier: notifier);
}

void main() {
  group('RoadmapNotifier', () {
    test('loadStatus sets hasRoadmap false when no roadmap', () async {
      final (:container, :adapter, :notifier) = _setup();
      await notifier.loadStatus();

      final state = container.read(roadmapProvider);
      expect(state.isLoading, false);
      expect(state.hasRoadmap, false);
      expect(state.generationStatus, 'idle');
      expect(state.roadmap, isNull);
      container.dispose();
    });

    test('loadStatus loads roadmap when hasRoadmap is true', () async {
      final (:container, :adapter, :notifier) = _setup(
        statusResponse: {'generation_status': 'ready', 'has_roadmap': true},
        roadmapResponse: {
          'id': 'r1',
          'summary': {'key_message': 'Go!'},
          'phases': [
            {'id': 'p1', 'title': 'Phase 1', 'completed': false, 'actions': [], 'skills': []},
          ],
          'status': 'active',
        },
      );
      await notifier.loadStatus();

      final state = container.read(roadmapProvider);
      expect(state.isLoading, false);
      expect(state.hasRoadmap, true);
      expect(state.roadmap, isNotNull);
      expect(state.roadmap!['id'], 'r1');
      container.dispose();
    });

    test('loadStatus handles error gracefully', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      final svc = RoadmapService.withDio(dio);
      adapter.onGet('/roadmap/status', (server) {
        server.reply(500, {'detail': 'Internal error'});
      });
      final container = ProviderContainer(
        overrides: [roadmapServiceProvider.overrideWithValue(svc)],
      );
      final notifier = container.read(roadmapProvider.notifier);
      await notifier.loadStatus();

      final state = container.read(roadmapProvider);
      expect(state.isLoading, false);
      container.dispose();
    });

    test('togglePhaseComplete reloads roadmap', () async {
      final (:container, :adapter, :notifier) = _setup(
        statusResponse: {'generation_status': 'ready', 'has_roadmap': true},
        roadmapResponse: {
          'id': 'r1',
          'summary': {},
          'phases': [
            {'id': 'p1', 'title': 'Phase 1', 'completed': false, 'actions': [], 'skills': []},
          ],
          'status': 'active',
        },
      );
      await notifier.loadStatus();

      adapter.onPatch('/roadmap/phases/p1/complete', (server) {
        server.reply(200, {'id': 'p1', 'completed': true});
      });

      await notifier.togglePhaseComplete('p1');
      container.dispose();
    });

    test('createRoadmap sets state correctly', () async {
      final (:container, :adapter, :notifier) = _setup();
      await notifier.loadStatus();

      adapter.onPost('/roadmap/manual', (server) {
        server.reply(200, {
          'id': 'manual-1',
          'summary': null,
          'phases': [
            {'id': 'p1', 'title': 'Custom Phase', 'completed': false},
          ],
          'status': 'active',
        });
      }, data: Matchers.any);

      await notifier.createRoadmap([
        {'title': 'Custom Phase', 'duration_weeks': 4},
      ]);

      final state = container.read(roadmapProvider);
      expect(state.hasRoadmap, true);
      expect(state.generationStatus, 'ready');
      expect(state.roadmap!['id'], 'manual-1');
      container.dispose();
    });

    test('deletePhase reloads roadmap', () async {
      final (:container, :adapter, :notifier) = _setup(
        statusResponse: {'generation_status': 'ready', 'has_roadmap': true},
        roadmapResponse: {
          'id': 'r1',
          'summary': {},
          'phases': [
            {'id': 'p1', 'title': 'Phase 1', 'completed': false, 'actions': [], 'skills': []},
          ],
          'status': 'active',
        },
      );
      await notifier.loadStatus();

      adapter.onDelete('/roadmap/phases/p1', (server) {
        server.reply(204, null);
      });

      await notifier.deletePhase('p1');
      container.dispose();
    });

    test('restoreRoadmap updates state', () async {
      final (:container, :adapter, :notifier) = _setup();
      await notifier.loadStatus();

      adapter.onPost('/roadmap/old-1/restore', (server) {
        server.reply(200, {
          'id': 'old-1',
          'summary': {},
          'phases': [],
          'status': 'active',
        });
      });

      await notifier.restoreRoadmap('old-1');

      final state = container.read(roadmapProvider);
      expect(state.hasRoadmap, true);
      expect(state.roadmap!['id'], 'old-1');
      container.dispose();
    });

    test('updatePhaseNotes updates phase and reloads', () async {
      final (:container, :adapter, :notifier) = _setup(
        statusResponse: {'generation_status': 'ready', 'has_roadmap': true},
        roadmapResponse: {
          'id': 'r1',
          'summary': {},
          'phases': [
            {'id': 'p1', 'title': 'Phase 1', 'completed': false, 'actions': [], 'skills': [], 'user_notes': ''},
          ],
          'status': 'active',
        },
      );
      await notifier.loadStatus();

      adapter.onPut('/roadmap/phases/p1', (server) {
        server.reply(200, {'id': 'p1', 'user_notes': 'My notes'});
      }, data: Matchers.any);

      await notifier.updatePhaseNotes('p1', 'My notes');
      container.dispose();
    });
  });

  group('RegenerationStatusNotifier', () {
    test('loads regeneration status on build', () async {
      final (:container, :adapter, :notifier) = _setup();
      adapter.onGet('/roadmap/regeneration-status', (server) {
        server.reply(200, {
          'used': 2,
          'limit': 5,
          'remaining': 3,
          'resets_at': '2026-04-01T00:00:00+00:00',
        });
      });

      final result = await container.read(regenerationStatusProvider.future);
      expect(result['remaining'], 3);
      expect(result['used'], 2);
      container.dispose();
    });

    test('new user shows full remaining count', () async {
      final (:container, :adapter, :notifier) = _setup();
      adapter.onGet('/roadmap/regeneration-status', (server) {
        server.reply(200, {
          'used': 0,
          'limit': 5,
          'remaining': 5,
          'resets_at': '2026-04-01T00:00:00+00:00',
        });
      });

      final result = await container.read(regenerationStatusProvider.future);
      expect(result['remaining'], 5);
      expect(result['used'], 0);
      container.dispose();
    });
  });
}
