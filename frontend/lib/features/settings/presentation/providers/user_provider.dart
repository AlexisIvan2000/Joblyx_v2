import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/settings/data/user_service.dart';

final userServiceProvider = Provider((_) => UserService());

final userProvider = AsyncNotifierProvider<UserNotifier, Map<String, dynamic>>(
  UserNotifier.new,
);

class UserNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final svc = ref.watch(userServiceProvider);
    return svc.getMe();
  }

  /// Recharge complète depuis le serveur (pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(userServiceProvider).getMe());
  }

  /// Met à jour le nom/prénom de manière optimiste.
  void updateName({required String firstName, required String lastName}) {
    final current = state.whenOrNull(data: (d) => d);
    if (current == null) return;
    state = AsyncData({...current, 'first_name': firstName, 'last_name': lastName});
  }

  /// Met à jour l'email de manière optimiste.
  void updateEmail(String newEmail) {
    final current = state.whenOrNull(data: (d) => d);
    if (current == null) return;
    state = AsyncData({...current, 'email': newEmail, 'pending_email': null});
  }

  /// Met à jour l'avatar de manière optimiste.
  void updateAvatar(String avatarUrl) {
    final current = state.whenOrNull(data: (d) => d);
    if (current == null) return;
    state = AsyncData({...current, 'avatar_url': avatarUrl});
  }
}
