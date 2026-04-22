import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class DashboardNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final response = await apiClient.get('/api/user/dashboard');
    return response.data as Map<String, dynamic>;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, Map<String, dynamic>>(() {
  return DashboardNotifier();
});
