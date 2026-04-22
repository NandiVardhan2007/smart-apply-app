import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class EmailAgentState {
  final bool isLoading;
  final bool isAuthorized;
  final Map<String, dynamic>? data;
  final String? lastThreadId;
  final String? error;

  EmailAgentState({
    this.isLoading = false,
    this.isAuthorized = false,
    this.data,
    this.lastThreadId,
    this.error,
  });

  EmailAgentState copyWith({
    bool? isLoading,
    bool? isAuthorized,
    Map<String, dynamic>? data,
    String? lastThreadId,
    String? error,
  }) {
    return EmailAgentState(
      isLoading: isLoading ?? this.isLoading,
      isAuthorized: isAuthorized ?? this.isAuthorized,
      data: data ?? this.data,
      lastThreadId: lastThreadId ?? this.lastThreadId,
      error: error ?? this.error,
    );
  }
}

class EmailAgentNotifier extends Notifier<EmailAgentState> {
  @override
  EmailAgentState build() {
    return EmailAgentState();
  }

  Future<void> init() async {
    // Check if user is authorized already by checking the dashboard data
    final dashboardData = ref.read(dashboardProvider).value;
    final user = dashboardData?['user'];
    
    if (user != null && user['google_credentials'] != null) {
      state = state.copyWith(isAuthorized: true);
      await scanEmails();
    }
  }

  Future<String?> getAuthUrl() async {
    final dashboardData = ref.read(dashboardProvider).value;
    final user = dashboardData?['user'];
    
    if (user == null) {
      state = state.copyWith(error: 'User data not found. Please refresh dashboard.');
      return null;
    }

    final userId = user['id'] ?? user['_id'];
    if (userId == null) {
      state = state.copyWith(error: 'User ID missing in dashboard data.');
      return null;
    }

    try {
      final response = await apiClient.get(
        '${ApiConstants.emailAuthUrl}?user_id=$userId',
      );
      return response.data['url'];
    } catch (e) {
      state = state.copyWith(error: 'Failed to connection session: $e');
      return null;
    }
  }

  Future<void> scanEmails() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.post(ApiConstants.emailAgentScan, data: {});
      if (response.data['error'] != null) {
        if (response.data['error'].toString().contains('no Google OAuth')) {
           state = state.copyWith(isLoading: false, isAuthorized: false);
        } else {
           state = state.copyWith(isLoading: false, error: response.data['error']);
        }
      } else {
        state = state.copyWith(
          isLoading: false, 
          isAuthorized: true,
          data: response.data,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAuthorized() async {
     state = state.copyWith(isAuthorized: true);
     await scanEmails();
  }

  Future<void> generateDraft(String threadId, String threadContext, String instruction) async {
    state = state.copyWith(isLoading: true, error: null, lastThreadId: threadId);
    try {
      final response = await apiClient.post(
        ApiConstants.emailAgentDraftReply,
        data: {
          'thread_context': threadContext,
          'user_instruction': instruction,
        },
      );
      
      if (response.data['error'] != null) {
        state = state.copyWith(isLoading: false, error: response.data['error']);
      } else {
        // Update the state data with the new draft for the UI to display
        final newData = Map<String, dynamic>.from(state.data ?? {});
        newData['last_draft'] = response.data['draft'];
        state = state.copyWith(isLoading: false, data: newData);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendReply(String threadId, String body, {String? subject}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.post(
        ApiConstants.emailAgentSendReply,
        data: {
          'thread_id': threadId,
          'reply_body': body,
          'subject': subject,
        },
      );
      
      if (response.data['error'] != null) {
        state = state.copyWith(isLoading: false, error: response.data['error']);
        return false;
      } else {
        state = state.copyWith(isLoading: false);
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final emailAgentProvider = NotifierProvider<EmailAgentNotifier, EmailAgentState>(() {
  return EmailAgentNotifier();
});
