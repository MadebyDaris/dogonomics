import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:Dogonomics/backend/api_client.dart';
import 'package:Dogonomics/backend/api_config.dart';
import 'package:Dogonomics/backend/dogonomicsApi.dart';

/// Service for managing WebSocket connections to the Dogonomics backend.
///
/// Provides real-time streaming for:
///   - Quote updates per symbol: `connectQuotes('AAPL')`
///   - General news feed: `connectNews()`
///
/// Automatically reconnects with exponential back-off on disconnect.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  bool _disposed = false;

  /// Connect to real-time quote updates for [symbol].
  /// Returns a broadcast stream of parsed quote JSON maps.
  Stream<QuoteData> connectQuotes(String symbol) {
    final path = '/ws/quotes/$symbol';
    return _connect(path).map((data) => QuoteData.fromJson(data));
  }

  /// Connect to real-time news updates.
  /// Returns a broadcast stream of parsed news JSON maps.
  Stream<NewsItem> connectNews() {
    final path = '/ws/news';
    return _connect(path).map((data) => NewsItem.fromJson(data));
  }

  /// Raw connection returning parsed JSON maps.
  Stream<Map<String, dynamic>> _connect(String path) {
    _disposed = false;
    _controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        // Auto-dispose when last listener unsubscribes
        if (!(_controller?.hasListener ?? true)) {
          dispose();
        }
      },
    );

    _doConnect(path);
    return _controller!.stream;
  }

  Future<void> _doConnect(String path) async {
    if (_disposed) return;

    try {
      // Get Firebase token for WebSocket auth
      final queryParams = <String, String>{};
      final token = await ApiClient.getToken();
      if (token != null) {
        queryParams['token'] = token;
      }
      if (ApiConfig.apiKey.isNotEmpty) {
        queryParams['api_key'] = ApiConfig.apiKey;
      }

      final wsUri = Uri.parse('${ApiConfig.wsBaseUrl}$path').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      _channel = WebSocketChannel.connect(wsUri);

      _reconnectAttempts = 0; // Reset on successful connection

      _channel!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final data = json.decode(message as String);
            if (data is Map<String, dynamic>) {
              _controller?.add(data);
            }
          } catch (e) {
            // Ignore non-JSON messages (e.g. heartbeats)
          }
        },
        onDone: () {
          if (!_disposed) _scheduleReconnect(path);
        },
        onError: (error) {
          if (!_disposed) _scheduleReconnect(path);
        },
      );
    } catch (e) {
      if (!_disposed) _scheduleReconnect(path);
    }
  }

  void _scheduleReconnect(String path) {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    // Exponential back-off: 1s, 2s, 4s, 8s … capped at 30s
    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, 30),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _doConnect(path);
    });
  }

  /// Close the WebSocket connection and clean up resources.
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }

  /// Whether the service is currently connected.
  bool get isConnected => _channel != null && !_disposed;
}
