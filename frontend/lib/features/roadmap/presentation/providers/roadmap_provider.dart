import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';

final roadmapServiceProvider = Provider((_) => RoadmapService());

class RoadmapState {
  final bool isLoading;
  final String generationStatus; // idle | generating | ready | error
  final bool hasRoadmap;
  final Map<String, dynamic>? roadmap;

  const RoadmapState({
    this.isLoading = true,
    this.generationStatus = 'idle',
    this.hasRoadmap = false,
    this.roadmap,
  });

  RoadmapState copyWith({
    bool? isLoading,
    String? generationStatus,
    bool? hasRoadmap,
    Map<String, dynamic>? roadmap,
    bool clearRoadmap = false,
  }) {
    return RoadmapState(
      isLoading: isLoading ?? this.isLoading,
      generationStatus: generationStatus ?? this.generationStatus,
      hasRoadmap: hasRoadmap ?? this.hasRoadmap,
      roadmap: clearRoadmap ? null : (roadmap ?? this.roadmap),
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

  Future<void> loadStatus() async {
    try {
      final status = await _svc.getStatus();
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
    state = state.copyWith(generationStatus: 'generating', isLoading: false);

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
      if (eventType == 'complete') {
        await loadRoadmap();
        state = state.copyWith(
          generationStatus: 'ready',
          hasRoadmap: true,
        );
        // Refresh regeneration count
        ref.invalidate(regenerationStatusProvider);
      } else if (eventType == 'error') {
        state = state.copyWith(generationStatus: 'error');
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
