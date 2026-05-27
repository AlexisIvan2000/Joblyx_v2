import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';

/// Service roadmap factice qui rejoue une liste d'événements SSE en mémoire.
class _FakeRoadmapService extends RoadmapService {
  _FakeRoadmapService(this._events)
      : super.withDio(Dio(BaseOptions(baseUrl: 'http://test')));

  final List<Map<String, dynamic>> _events;

  @override
  Future<Map<String, dynamic>> getStatus() async =>
      {'generation_status': 'idle', 'has_roadmap': false};

  @override
  Future<Map<String, dynamic>> getRoadmap() async =>
      {'id': 'r1', 'summary': {}, 'phases': [], 'status': 'active'};

  @override
  Future<Map<String, dynamic>> getRegenerationStatus() async =>
      {'used': 1, 'limit': 5, 'remaining': 4, 'resets_at': '2026-04-01T00:00:00Z'};

  @override
  Stream<Map<String, dynamic>> generateWithAI({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
    CancelToken? cancelToken,
  }) async* {
    for (final event in _events) {
      yield event;
    }
  }
}

/// Service roadmap factice qui émet un chunk puis se bloque jusqu'à l'annulation.
class _CancellableRoadmapService extends RoadmapService {
  _CancellableRoadmapService()
      : super.withDio(Dio(BaseOptions(baseUrl: 'http://test')));

  final List<CancelToken> receivedTokens = [];

  @override
  Future<Map<String, dynamic>> getStatus() async =>
      {'generation_status': 'idle', 'has_roadmap': false};

  @override
  Stream<Map<String, dynamic>> generateWithAI({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
    CancelToken? cancelToken,
  }) async* {
    receivedTokens.add(cancelToken!);
    yield {'event': 'chunk', 'data': {'text': 'partiel'}};
    await cancelToken.whenCancel;
    throw DioException(
      requestOptions: RequestOptions(path: '/roadmap/generate'),
      type: DioExceptionType.cancel,
    );
  }
}

/// Lance generateWithAI avec des paramètres par défaut.
Future<void> _gen(RoadmapNotifier notifier) => notifier.generateWithAI(
      level: 'junior',
      yearsExperience: 0,
      targetJobs: const ['Dev'],
      city: 'Paris',
      province: 'IDF',
      language: 'fr',
      skills: const [],
    );

void main() {
  group('RoadmapNotifier.generateWithAI', () {
    test('passe à ready sur événement complete', () async {
      final svc = _FakeRoadmapService([
        {'event': 'chunk', 'data': {'text': '{"phases":['}},
        {'event': 'complete', 'data': {}},
      ]);
      final container = ProviderContainer(
        overrides: [roadmapServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(roadmapProvider.notifier);
      // Laisse passer le loadStatus déclenché par build()
      await Future.delayed(const Duration(milliseconds: 10));

      await _gen(notifier);

      final state = container.read(roadmapProvider);
      expect(state.generationStatus, 'ready');
      expect(state.hasRoadmap, true);
      expect(state.streamingText, isEmpty);
    });

    test('passe à error sur événement error', () async {
      final svc = _FakeRoadmapService([
        {'event': 'error', 'data': {}},
      ]);
      final container = ProviderContainer(
        overrides: [roadmapServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(roadmapProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      await _gen(notifier);

      expect(container.read(roadmapProvider).generationStatus, 'error');
    });

    test('une nouvelle génération annule la précédente (anti-chevauchement)',
        () async {
      final svc = _CancellableRoadmapService();
      final container = ProviderContainer(
        overrides: [roadmapServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(roadmapProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      // gen1 démarre et se bloque
      final gen1 = _gen(notifier);
      await Future.delayed(const Duration(milliseconds: 20));
      // gen2 démarre : doit annuler gen1 via _newGenToken()
      final gen2 = _gen(notifier);
      await Future.delayed(const Duration(milliseconds: 20));

      // gen1 se termine proprement (annulation avalée)
      await gen1;

      expect(svc.receivedTokens.length, 2);
      expect(svc.receivedTokens[0].isCancelled, isTrue);
      expect(svc.receivedTokens[1].isCancelled, isFalse);

      // Nettoyage : annule gen2 pour qu'il se termine aussi
      svc.receivedTokens[1].cancel();
      await gen2;
    });
  });
}
