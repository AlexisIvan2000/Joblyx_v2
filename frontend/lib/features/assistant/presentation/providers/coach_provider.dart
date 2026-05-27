import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/assistant/data/coach_service.dart';

final coachServiceProvider = Provider((_) => CoachService());

// Usage

final coachUsageProvider =
    AsyncNotifierProvider<CoachUsageNotifier, Map<String, dynamic>>(
        CoachUsageNotifier.new);

class CoachUsageNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return await ref.read(coachServiceProvider).getUsage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(coachServiceProvider).getUsage());
  }
}

// Historique

final coachHistoryProvider =
    AsyncNotifierProvider<CoachHistoryNotifier, List<Map<String, dynamic>>>(
        CoachHistoryNotifier.new);

class CoachHistoryNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return await ref.read(coachServiceProvider).getHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(coachServiceProvider).getHistory());
  }

  Future<void> deleteSession(String id) async {
    await ref.read(coachServiceProvider).deleteSession(id);
    await refresh();
    ref.invalidate(coachUsageProvider);
  }

  Future<int> deleteAll() async {
    final count = await ref.read(coachServiceProvider).deleteAll();
    await refresh();
    ref.invalidate(coachUsageProvider);
    return count;
  }
}

// Analyse (state pour le streaming)

class CoachAnalysisState {
  final String status; // idle | analyzing | done | error
  final String streamingText;
  final Map<String, dynamic>? analysis;
  final String? errorMessage;

  const CoachAnalysisState({
    this.status = 'idle',
    this.streamingText = '',
    this.analysis,
    this.errorMessage,
  });

  CoachAnalysisState copyWith({
    String? status,
    String? streamingText,
    Map<String, dynamic>? analysis,
    String? errorMessage,
    bool clearAnalysis = false,
  }) {
    return CoachAnalysisState(
      status: status ?? this.status,
      streamingText: streamingText ?? this.streamingText,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final coachAnalysisProvider =
    NotifierProvider<CoachAnalysisNotifier, CoachAnalysisState>(
        CoachAnalysisNotifier.new);

class CoachAnalysisNotifier extends Notifier<CoachAnalysisState> {
  CancelToken? _cancelToken;

  @override
  CoachAnalysisState build() => const CoachAnalysisState();

  /// Tente d'extraire des sections complètes du buffer JSON pour affichage progressif.
  Map<String, dynamic>? _tryParsePartial(String buffer) {
    try {
      // Tenter de parser le JSON complet (cas où le stream est rapide)
      return jsonDecode(buffer) as Map<String, dynamic>;
    } catch (_) {
      // JSON incomplet — parsing progressif par comptage d'accolades
      // Chercher le score en premier (apparaît tôt dans le JSON)
      final scoreMatch = RegExp(r'"compatibility_score"\s*:\s*(\d+)').firstMatch(buffer);
      final summaryMatch = RegExp(r'"summary"\s*:\s*"([^"]*(?:\\.[^"]*)*)"').firstMatch(buffer);

      if (scoreMatch != null) {
        return {
          'compatibility_score': int.tryParse(scoreMatch.group(1)!) ?? 0,
          if (summaryMatch != null) 'summary': summaryMatch.group(1)!.replaceAll(r'\"', '"'),
        };
      }
      return null;
    }
  }

  /// Lance l'analyse en streaming. La boucle vit dans le notifier, l'écran
  /// observe l'état. Le CancelToken permet d'arrêter le flux si l'utilisateur quitte.
  Future<void> analyze({
    required String cvPath,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String language = 'fr',
  }) async {
    // Annule une analyse précédente encore en cours
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = const CoachAnalysisState(status: 'analyzing');

    final svc = ref.read(coachServiceProvider);

    try {
      await for (final event in svc.analyzeStream(
        cvPath: cvPath,
        jobDescription: jobDescription,
        jobTitle: jobTitle,
        companyName: companyName,
        language: language,
        cancelToken: cancelToken,
      )) {
        final eventType = event['event'] as String;
        final data = event['data'] as Map<String, dynamic>;

        if (eventType == 'chunk') {
          final text = data['text'] as String? ?? '';
          final newText = state.streamingText + text;
          final partial = _tryParsePartial(newText);
          state = state.copyWith(
            streamingText: newText,
            analysis: partial,
          );
        } else if (eventType == 'analysis') {
          state = state.copyWith(
            status: 'done',
            analysis: data,
            streamingText: '',
          );
          // Rafraîchir l'historique et l'usage
          ref.invalidate(coachHistoryProvider);
          ref.invalidate(coachUsageProvider);
        } else if (eventType == 'error') {
          state = state.copyWith(
            status: 'error',
            errorMessage: data['error'] as String?,
            streamingText: '',
          );
        }
      }
    } on DioException catch (e) {
      // Annulation volontaire : on ne traite pas comme une erreur
      if (CancelToken.isCancel(e)) return;
      state = state.copyWith(status: 'error', streamingText: '');
      rethrow;
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  /// Annule l'analyse en cours (ex. l'utilisateur quitte l'écran résultat).
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  /// Reset l'état pour une nouvelle analyse.
  void reset() {
    cancel();
    state = const CoachAnalysisState();
  }
}
