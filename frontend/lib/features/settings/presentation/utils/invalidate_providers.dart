import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/settings/presentation/providers/user_provider.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';

/// Invalide tous les providers liés à l'utilisateur.
/// A appeler au logout et suppression de compte pour éviter
/// que les données de l'ancien compte restent en cache.
void invalidateUserProviders(WidgetRef ref) {
  ref.invalidate(userProvider);
  ref.invalidate(roadmapProvider);
  ref.invalidate(regenerationStatusProvider);
  ref.invalidate(applicationsProvider);
  ref.invalidate(coachUsageProvider);
  ref.invalidate(coachHistoryProvider);
  ref.invalidate(coachAnalysisProvider);
  ref.invalidate(interviewUsageProvider);
  ref.invalidate(interviewHistoryProvider);
  ref.invalidate(interviewChatProvider);
}
