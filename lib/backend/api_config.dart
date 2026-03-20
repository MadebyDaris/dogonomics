/// Centralized API configuration for the Dogonomics backend.
///
/// The base URL can be overridden at build time:
///   flutter run --dart-define=API_URL=https://api.dogonomics.com
///
/// Or via environment variable in CI/CD.
class ApiConfig {
  ApiConfig._();

  /// The backend base URL.
  /// Uses --dart-define=API_URL when provided, otherwise defaults to dev IP.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.148:8080',
  );

  /// Shared API key sent in X-API-Key header.
  /// Example:
  ///   flutter run --dart-define=API_KEY=your_app_api_key
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  /// WebSocket base URL (auto-derived from baseUrl).
  /// Converts http:// → ws:// and https:// → wss://
  static String get wsBaseUrl {
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    }
    return baseUrl.replaceFirst('http://', 'ws://');
  }

  /// Default timeout for most API calls.
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Long timeout for expensive operations like sentiment analysis.
  static const Duration longTimeout = Duration(seconds: 60);
}
