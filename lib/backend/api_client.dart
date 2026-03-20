import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

/// Authenticated HTTP client that automatically injects Firebase ID tokens.
///
/// Usage:
///   final data = await ApiClient.get('/stock/AAPL');
///   final body = await ApiClient.post('/finbert/inference', body: {'text': '...'});
class ApiClient {
  ApiClient._();

  /// GET request with auth headers.
  static Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final headers = await _authHeaders();
    return http.get(uri, headers: headers)
        .timeout(timeout ?? ApiConfig.defaultTimeout);
  }

  /// POST request with auth headers and JSON body.
  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, null);
    final headers = await _authHeaders();
    return http.post(
      uri,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    ).timeout(timeout ?? ApiConfig.defaultTimeout);
  }

  /// Build the full URI from path and optional query params.
  static Uri _buildUri(String path, Map<String, String>? queryParams) {
    final base = ApiConfig.baseUrl;
    final url = '$base$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }
    return Uri.parse(url);
  }

  /// Get authorization headers with Firebase ID token.
  static Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (ApiConfig.apiKey.isNotEmpty) {
      headers['X-API-Key'] = ApiConfig.apiKey;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      // If token retrieval fails, proceed without auth
      // (the server will return 401 if auth is required)
    }

    return headers;
  }

  /// Get a fresh Firebase ID token string (for WebSocket auth).
  static Future<String?> getToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (_) {}
    return null;
  }
}
