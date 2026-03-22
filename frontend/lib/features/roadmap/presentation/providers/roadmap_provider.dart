import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';

final roadmapServiceProvider = Provider((_) => RoadmapService());

class RoadmapState {
  final bool isLoading;
  final String generationStatus; // idle | generating | ready | error
  final bool hasRoadmap;
  final Map<String, dynamic>? roadmap;
  final String streamingText;
  final List<Map<String, dynamic>> streamingPhases;

  const RoadmapState({
    this.isLoading = true,
    this.generationStatus = 'idle',
    this.hasRoadmap = false,
    this.roadmap,
    this.streamingText = '',
    this.streamingPhases = const [],
  });

  RoadmapState copyWith({
    bool? isLoading,
    String? generationStatus,
    bool? hasRoadmap,
    Map<String, dynamic>? roadmap,
    String? streamingText,
    List<Map<String, dynamic>>? streamingPhases,
    bool clearRoadmap = false,
  }) {
    return RoadmapState(
      isLoading: isLoading ?? this.isLoading,
      generationStatus: generationStatus ?? this.generationStatus,
      hasRoadmap: hasRoadmap ?? this.hasRoadmap,
      roadmap: clearRoadmap ? null : (roadmap ?? this.roadmap),
      streamingText: streamingText ?? this.streamingText,
      streamingPhases: streamingPhases ?? this.streamingPhases,
    );
  }
}

final roadmapProvider =
    NotifierProvider<RoadmapNotifier, RoadmapState>(RoadmapNotifier.new);

class RoadmapNotifier extends Notifier<RoadmapState> {
  @override
  RoadmapState build() {
    Future.microtask(() => loadStatus());
    return const RoadmapState();
  }

  RoadmapService get _svc => ref.read(roadmapServiceProvider);

  // ── Parsing progressif du JSON GPT ──────────────────────────
  int _parsedPhaseCount = 0;

  /// Tente d'extraire les phases complètes du buffer JSON accumulé.
  /// Utilise le comptage d'accolades pour détecter les objets complets.
  void _tryParsePhases(String buffer) {
    // Chercher le début du tableau "phases"
    final phasesStart = buffer.indexOf('"phases"');
    if (phasesStart == -1) return;

    // Trouver le [ d'ouverture du tableau
    final bracketStart = buffer.indexOf('[', phasesStart);
    if (bracketStart == -1) return;

    // Parcourir après le [ pour extraire les objets phase complets
    final content = buffer.substring(bracketStart + 1);
    final phases = <Map<String, dynamic>>[];
    int depth = 0;
    int objStart = -1;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < content.length; i++) {
      final c = content[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (c == '{') {
        if (depth == 0) objStart = i;
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && objStart != -1) {
          // Objet phase complet
          final objStr = content.substring(objStart, i + 1);
          try {
            final parsed = jsonDecode(objStr) as Map<String, dynamic>;
            phases.add(parsed);
          } catch (_) {
            // JSON invalide — ignorer (sera rattrapé à la fin)
          }
          objStart = -1;
        }
      }
    }

    // Ne mettre à jour que si on a trouvé de nouvelles phases
    if (phases.length > _parsedPhaseCount) {
      _parsedPhaseCount = phases.length;
      state = state.copyWith(streamingPhases: phases);
    }
  }

  Future<void> loadStatus() async {
    try {
      final status = await _svc.getStatus();
      if (!ref.mounted) return;
      final genStatus = status['generation_status'] as String;
      final hasRoadmap = status['has_roadmap'] as bool;

      state = state.copyWith(
        isLoading: false,
        generationStatus: genStatus,
        hasRoadmap: hasRoadmap,
      );

      if (hasRoadmap) {
        await loadRoadmap();
      }
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadRoadmap() async {
    try {
      final roadmap = await _svc.getRoadmap();
      state = state.copyWith(roadmap: roadmap);
    } catch (_) {}
  }

  /// Generate roadmap with AI via SSE streaming.
  /// Returns a Stream so the UI can react to events.
  /// Traite les events SSE communs (chunk / complete / error).
  void _handleStreamEvent(Map<String, dynamic> event) {
    final eventType = event['event'] as String;
    if (eventType == 'chunk') {
      final text = (event['data'] as Map<String, dynamic>)['text'] as String? ?? '';
      final newText = state.streamingText + text;
      state = state.copyWith(streamingText: newText);
      _tryParsePhases(newText);
    }
  }

  Stream<Map<String, dynamic>> generateWithAI({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
  }) async* {
    _parsedPhaseCount = 0;
    state = state.copyWith(
      generationStatus: 'generating', isLoading: false,
      streamingText: '', streamingPhases: [],
    );

    await for (final event in _svc.generateWithAI(
      level: level,
      yearsExperience: yearsExperience,
      targetJobs: targetJobs,
      city: city,
      province: province,
      language: language,
      previousField: previousField,
      skills: skills,
    )) {
      yield event;

      final eventType = event['event'] as String;
      if (eventType == 'chunk') {
        _handleStreamEvent(event);
      } else if (eventType == 'complete') {
        await loadRoadmap();
        state = state.copyWith(
          generationStatus: 'ready',
          hasRoadmap: true,
          streamingText: '',
          streamingPhases: [],
        );
        ref.invalidate(regenerationStatusProvider);
      } else if (eventType == 'error') {
        state = state.copyWith(
          generationStatus: 'error',
          streamingText: '',
          streamingPhases: [],
        );
      }
    }
  }

  /// Régénère la roadmap avec les données carrière existantes.
  Stream<Map<String, dynamic>> regenerate() async* {
    _parsedPhaseCount = 0;
    state = state.copyWith(
      generationStatus: 'generating', isLoading: false,
      streamingText: '', streamingPhases: [],
    );

    await for (final event in _svc.regenerate()) {
      yield event;

      final eventType = event['event'] as String;
      if (eventType == 'chunk') {
        _handleStreamEvent(event);
      } else if (eventType == 'complete') {
        await loadRoadmap();
        state = state.copyWith(
          generationStatus: 'ready',
          hasRoadmap: true,
          streamingText: '',
          streamingPhases: [],
        );
        ref.invalidate(regenerationStatusProvider);
      } else if (eventType == 'error') {
        state = state.copyWith(
          generationStatus: 'error',
          streamingText: '',
          streamingPhases: [],
        );
      }
    }
  }

  // ─── Phase operations (use phase ID) ──────────────────────────

  Future<void> togglePhaseComplete(String phaseId) async {
    await _svc.togglePhaseComplete(phaseId);
    await loadRoadmap();
  }

  Future<void> toggleActionComplete(String phaseId, int actionIndex) async {
    await _svc.toggleActionComplete(phaseId, actionIndex);
    await loadRoadmap();
  }

  Future<void> toggleSkillComplete(String phaseId, int skillIndex) async {
    await _svc.toggleSkillComplete(phaseId, skillIndex);
    await loadRoadmap();
  }

  Future<void> addPhase(Map<String, dynamic> phase) async {
    await _svc.addPhase(phase);
    await loadRoadmap();
  }

  Future<void> deletePhase(String phaseId) async {
    await _svc.deletePhase(phaseId);
    await loadRoadmap();
  }

  Future<void> updatePhase(String phaseId, Map<String, dynamic> data) async {
    await _svc.updatePhase(phaseId, data);
    await loadRoadmap();
  }

  Future<void> createRoadmap(List<Map<String, dynamic>> phases) async {
    final roadmap = await _svc.createManual(phases);
    state = state.copyWith(
      roadmap: roadmap,
      hasRoadmap: true,
      generationStatus: 'ready',
    );
  }

  Future<void> restoreRoadmap(String roadmapId) async {
    final updated = await _svc.restoreRoadmap(roadmapId);
    state = state.copyWith(
        roadmap: updated, hasRoadmap: true, generationStatus: 'ready');
  }

  Future<void> updatePhaseNotes(String phaseId, String notes) async {
    await _svc.updatePhase(phaseId, {'user_notes': notes});
    await loadRoadmap();
  }
}

/// Regeneration status provider
final regenerationStatusProvider =
    AsyncNotifierProvider<RegenerationStatusNotifier, Map<String, dynamic>>(
  RegenerationStatusNotifier.new,
);

class RegenerationStatusNotifier
    extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final svc = ref.watch(roadmapServiceProvider);
    return svc.getRegenerationStatus();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(roadmapServiceProvider).getRegenerationStatus(),
    );
  }
}
