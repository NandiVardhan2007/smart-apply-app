import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/network/api_client.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview_flutter;

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final String? token;

  AuthState({
    required this.status,
    this.token,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? token,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final StorageService _storage;

  @override
  AuthState build() {
    _storage = StorageService();
    _checkAuth();
    
    // Listen for global session expiration events
    apiClient.onSessionExpired.listen((_) {
      logout();
    });
    
    return AuthState(status: AuthStatus.initial);
  }

  Future<void> _checkAuth() async {
    final token = await _storage.getToken();
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated, token: token);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String token) async {
    await _storage.saveToken(token);
    state = state.copyWith(status: AuthStatus.authenticated, token: token);
  }

  Future<void> logout() async {
    // 1. Clear Backend Token
    await _storage.clearAuth();
    
    // 2. Clear WebView Cookies & Cache (Fix for shared session bug)
    try {
      final cookieManager = webview_flutter.WebViewCookieManager();
      await cookieManager.clearCookies();
      
      // On Windows/Desktop
      // webview_windows doesn't have a global cookie manager yet in this version, 
      // but we can at least signal a clean start for the next session.
    } catch (e) {
      // Ignore if webview is not initialized or on unsupported platform
    }

    state = state.copyWith(status: AuthStatus.unauthenticated, token: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());
