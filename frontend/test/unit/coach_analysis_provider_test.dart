import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/assistant/data/coach_service.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';

/// Service coach factice qui rejoue une liste d'événements SSE en mémoire.
class _FakeCoachService extends CoachService {
  _FakeCoachService(this._events)
      : super.withDio(Dio(BaseOptions(baseUrl: 'http://test')));

  final List<Map<String, dynamic>> _events;

  @override
  Stream<Map<String, dynamic>> analyzeStream({
    required String cvPath,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String language = 'fr',
    CancelToken? cancelToken,
  }) async* {
    for (final event in _events) {
      yield event;
    }
  }

  @override
  Future<Map<String, dynamic>> getUsage() async =>
      {'used': 0, 'limit': 3, 'remaining': 3};

  @override
  Future<List<Map<String, dynamic>>> getHistory() async => [];
}

/// Service coach factice qui émet un chunk puis se bloque jusqu'à l'annulation.
class _CancellableCoachService extends CoachService {
  _CancellableCoachService()
      : super.withDio(Dio(BaseOptions(baseUrl: 'http://test')));

  CancelToken? receivedToken;

  @override
  Stream<Map<String, dynamic>> analyzeStream({
    required String cvPath,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String language = 'fr',
    CancelToken? cancelToken,
  }) async* {
    receivedToken = cancelToken;
    yield {'event': 'chunk', 'data': {'text': 'partiel'}};
    // Reste en attente jusqu'à ce que le notifier annule le token
    await cancelToken!.whenCancel;
    throw DioException(
      requestOptions: RequestOptions(path: '/assistant/coach/analyze'),
      type: DioExceptionType.cancel,
    );
  }

  @override
  Future<Map<String, dynamic>> getUsage() async =>
      {'used': 0, 'limit': 3, 'remaining': 3};

  @override
  Future<List<Map<String, dynamic>>> getHistory() async => [];
}

ProviderContainer _container(List<Map<String, dynamic>> events) {
  final container = ProviderContainer(
    overrides: [coachServiceProvider.overrideWithValue(_FakeCoachService(events))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('CoachAnalysisNotifier.analyze', () {
    test('passe à done et stocke l\'analyse sur événement analysis', () async {
      final container = _container([
        {'event': 'chunk', 'data': {'text': 'partiel'}},
        {'event': 'analysis', 'data': {'compatibility_score': 80, 'summary': 'ok'}},
      ]);

      await container
          .read(coachAnalysisProvider.notifier)
          .analyze(cvPath: 'cv.pdf', jobDescription: 'desc');

      final state = container.read(coachAnalysisProvider);
      expect(state.status, 'done');
      expect(state.analysis!['compatibility_score'], 80);
      expect(state.streamingText, isEmpty);
    });

    test('passe à error sur événement error', () async {
      final container = _container([
        {'event': 'error', 'data': {'error': 'boom'}},
      ]);

      await container
          .read(coachAnalysisProvider.notifier)
          .analyze(cvPath: 'cv.pdf', jobDescription: 'desc');

      final state = container.read(coachAnalysisProvider);
      expect(state.status, 'error');
      expect(state.errorMessage, 'boom');
    });

    test('reset remet l\'état à idle', () async {
      final container = _container([
        {'event': 'analysis', 'data': {'compatibility_score': 50}},
      ]);
      final notifier = container.read(coachAnalysisProvider.notifier);

      await notifier.analyze(cvPath: 'cv.pdf', jobDescription: 'desc');
      notifier.reset();

      final state = container.read(coachAnalysisProvider);
      expect(state.status, 'idle');
      expect(state.analysis, isNull);
      expect(state.streamingText, isEmpty);
    });
  });

  group('CoachAnalysisNotifier.cancel', () {
    test('annule le stream sans erreur et sans passer à done', () async {
      final svc = _CancellableCoachService();
      final container = ProviderContainer(
        overrides: [coachServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(coachAnalysisProvider.notifier);

      // Démarre sans attendre, puis annule pendant le streaming
      final future = notifier.analyze(cvPath: 'cv.pdf', jobDescription: 'desc');
      await Future.delayed(const Duration(milliseconds: 20));
      notifier.cancel();

      // Le Future se termine proprement : l'annulation est avalée, pas de throw
      await future;

      expect(svc.receivedToken, isNotNull);
      expect(svc.receivedToken!.isCancelled, isTrue);
      // N'a jamais atteint l'analyse complète
      expect(container.read(coachAnalysisProvider).status, isNot('done'));
    });
  });
}
