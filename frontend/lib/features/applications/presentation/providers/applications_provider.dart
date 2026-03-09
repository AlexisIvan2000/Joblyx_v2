import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/applications/data/application_service.dart';

final applicationServiceProvider = Provider((_) => ApplicationService());

final applicationsProvider =
    AsyncNotifierProvider<ApplicationsNotifier, List<Map<String, dynamic>>>(
  ApplicationsNotifier.new,
);

class ApplicationsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final svc = ref.watch(applicationServiceProvider);
    final data = await svc.getAll();
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final svc = ref.read(applicationServiceProvider);
      final data = await svc.getAll();
      return data.cast<Map<String, dynamic>>();
    });
  }

  Future<void> create(Map<String, dynamic> data) async {
    final svc = ref.read(applicationServiceProvider);
    await svc.create(data);
    await refresh();
  }

  Future<void> delete(String id) async {
    final svc = ref.read(applicationServiceProvider);
    await svc.delete(id);
    await refresh();
  }
}
