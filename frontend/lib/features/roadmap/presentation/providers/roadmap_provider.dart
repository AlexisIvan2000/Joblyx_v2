import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/roadmap/data/roadmap_service.dart';

final roadmapServiceProvider = Provider((_) => RoadmapService());

/// Etat du roadmap screen
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
  Timer? _pollTimer;

  @override
  RoadmapState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    // Lancer le chargement initial
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

      if (genStatus == 'generating') {
        _startPolling();
      } else if (hasRoadmap) {
        await loadRoadmap();
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await _svc.getStatus();
        final genStatus = status['generation_status'] as String;
        final hasRoadmap = status['has_roadmap'] as bool;

        if (genStatus != 'generating') {
          _pollTimer?.cancel();
          state = state.copyWith(
            generationStatus: genStatus,
            hasRoadmap: hasRoadmap,
          );
          if (hasRoadmap) await loadRoadmap();
        }
      } catch (_) {}
    });
  }

  Future<void> loadRoadmap() async {
    try {
      final roadmap = await _svc.getRoadmap();
      state = state.copyWith(roadmap: roadmap);
    } catch (_) {
      // Erreur silencieuse, le UI réagira à l'absence de roadmap
    }
  }

  Future<void> generate() async {
    state = state.copyWith(generationStatus: 'generating');
    try {
      await _svc.generate();
      _startPolling();
    } catch (_) {
      state = state.copyWith(
        generationStatus: state.hasRoadmap ? 'ready' : 'error',
      );
      rethrow;
    }
  }

  Future<void> togglePhaseComplete(int phaseNumber) async {
    final roadmapId = state.roadmap?['id'] as String?;
    if (roadmapId == null) return;
    final updated = await _svc.togglePhaseComplete(roadmapId, phaseNumber);
    state = state.copyWith(roadmap: updated);
  }

  Future<void> toggleActionComplete(int phaseNumber, int actionIndex) async {
    final roadmapId = state.roadmap?['id'] as String?;
    if (roadmapId == null) return;
    final updated =
        await _svc.toggleActionComplete(roadmapId, phaseNumber, actionIndex);
    state = state.copyWith(roadmap: updated);
  }
}

/// Regeneration status provider (séparé car utilisé aussi dans dashboard/profile)
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
