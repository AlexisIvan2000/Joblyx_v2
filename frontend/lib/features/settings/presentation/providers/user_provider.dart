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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(userServiceProvider).getMe());
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    final svc = ref.read(userServiceProvider);
    final updated = await svc.updateProfile(
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
    );
    state = AsyncData(updated);
  }
}
