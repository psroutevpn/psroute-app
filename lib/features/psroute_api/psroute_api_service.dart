import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'psroute_api_service.g.dart';

/// PS Route Mobile API client.
/// Base URL: https://api.psroute.xyz:2087
class PSRouteApiService with InfraLogger {
  static const String baseUrl = 'https://api.psroute.xyz:2087';

  final Dio _dio;
  String? _authToken;
  final Completer<void> _initCompleter = Completer<void>();

  /// Future that resolves once init() has loaded the saved token.
  Future<void> get initialized => _initCompleter.future;

  PSRouteApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  /// Initialize: load saved token from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('psroute_auth_token');
      if (_authToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $_authToken';
      }
    } finally {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  /// Save auth token after login.
  Future<void> _saveToken(String token) async {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('psroute_auth_token', token);
  }

  /// Clear auth token on logout.
  Future<void> logout() async {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('psroute_auth_token');
  }

  bool get isAuthenticated => _authToken != null;

  // ─── Phase 1: Public Endpoints ────────────────────────────

  /// Remote config: feature flags, versioning, announcements.
  Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final response = await _dio.get('/app/config');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.warning('Failed to fetch app config', e);
      return {};
    }
  }

  /// Server list with health status.
  Future<Map<String, dynamic>> getServers() async {
    try {
      final response = await _dio.get('/servers');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.warning('Failed to fetch servers', e);
      return {'servers': [], 'fallback': true};
    }
  }

  /// Available subscription plans with prices.
  Future<List<Map<String, dynamic>>> getPlans() async {
    try {
      final response = await _dio.get('/plans');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['plans'] ?? []);
    } catch (e) {
      loggy.warning('Failed to fetch plans', e);
      return [];
    }
  }

  // ─── Phase 2: Auth ────────────────────────────────────────

  /// Authenticate with Telegram Login Widget data.
  /// Returns user info or throws on failure.
  Future<Map<String, dynamic>> authTelegram(Map<String, dynamic> telegramData) async {
    try {
      final response = await _dio.post('/auth/telegram', data: telegramData);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      await _saveToken(token);
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Пользователь не найден. Начните с @PSRouteBot.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Ошибка авторизации Telegram.');
      }
      rethrow;
    }
  }

  // ─── Phase 2: User ────────────────────────────────────────

  /// Current user profile and subscription status.
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/user/me');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw Exception('Сессия истекла. Войдите заново.');
      }
      rethrow;
    }
  }

  /// Detailed subscription info including traffic.
  Future<Map<String, dynamic>> getSubscription() async {
    try {
      final response = await _dio.get('/user/subscription');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw Exception('Сессия истекла. Войдите заново.');
      }
      rethrow;
    }
  }

  // ─── Phase 2: Payments ────────────────────────────────────

  /// Create a payment order. Returns payment URL or bot redirect.
  Future<Map<String, dynamic>> createPayment({
    required String plan,
    required String method,
  }) async {
    final response = await _dio.post('/payment/create', data: {
      'plan': plan,
      'method': method,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Poll payment status.
  Future<Map<String, dynamic>> getPaymentStatus(String orderId) async {
    final response = await _dio.get('/payment/status/$orderId');
    return response.data as Map<String, dynamic>;
  }

  // ─── Phase 3: Referrals ───────────────────────────────────

  /// Referral stats for current user.
  Future<Map<String, dynamic>> getReferralStats() async {
    final response = await _dio.get('/referral/stats');
    return response.data as Map<String, dynamic>;
  }

  /// Apply a referral code.
  Future<Map<String, dynamic>> applyReferral(String code) async {
    final response = await _dio.post('/referral/apply', data: {'code': code});
    return response.data as Map<String, dynamic>;
  }

  // ─── Phase 3: AI Proxy ────────────────────────────────────

  /// Available AI models list.
  Future<Map<String, dynamic>> getAIModels() async {
    final response = await _dio.get('/ai/models');
    return response.data as Map<String, dynamic>;
  }

  /// Send chat message to AI proxy.
  Future<Map<String, dynamic>> aiChat({
    required String model,
    required String message,
    String? conversationId,
  }) async {
    final response = await _dio.post('/ai/chat', data: {
      'model': model,
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// AI token usage stats.
  Future<Map<String, dynamic>> getAIUsage() async {
    final response = await _dio.get('/ai/usage');
    return response.data as Map<String, dynamic>;
  }

  // ─── Phase 3: Push Notifications ──────────────────────────

  /// Register device FCM token for push notifications.
  Future<void> registerDevice({
    required String fcmToken,
    String? deviceModel,
    String? appVersion,
    String? osVersion,
  }) async {
    await _dio.post('/device/register', data: {
      'fcm_token': fcmToken,
      if (deviceModel != null) 'device_model': deviceModel,
      if (appVersion != null) 'app_version': appVersion,
      if (osVersion != null) 'os_version': osVersion,
    });
  }
}

/// Global provider for PSRouteApiService.
@Riverpod(keepAlive: true)
PSRouteApiService psrouteApi(PsrouteApiRef ref) {
  final service = PSRouteApiService();
  service.init();
  return service;
}
