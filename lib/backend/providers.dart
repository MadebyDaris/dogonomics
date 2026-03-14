import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

/// ChatProvider manages chat history and LLM responses
/// Provides reactive state for chat message history
class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Add a user message to the chat history
  void addUserMessage(String text, {String? context}) {
    const uuid = Uuid();
    final message = ChatMessage(
      id: uuid.v4(),
      text: text,
      sender: 'user',
      timestamp: DateTime.now(),
      context: context,
    );
    _messages.add(message);
    _error = null;
    notifyListeners();
  }

  /// Add an assistant response to the chat history
  void addAssistantMessage(String text) {
    const uuid = Uuid();
    final message = ChatMessage(
      id: uuid.v4(),
      text: text,
      sender: 'assistant',
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    _error = null;
    notifyListeners();
  }

  /// Set loading state during LLM response generation
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message if LLM call fails
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear all chat history
  void clearHistory() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  /// Remove a message by ID
  void removeMessage(String messageId) {
    _messages.removeWhere((msg) => msg.id == messageId);
    notifyListeners();
  }
}

/// TickerProvider manages the live ticker tape data
/// Streams market sentiment from WebSocket endpoint
class TickerProvider extends ChangeNotifier {
  final List<TickerItem> _ticker = [];
  bool _isConnected = false;
  String? _error;
  final Map<String, DateTime> _lastUpdateTime = {}; // Rate limiting per symbol

  List<TickerItem> get ticker => List.unmodifiable(_ticker);
  bool get isConnected => _isConnected;
  String? get error => _error;

  /// Add a new ticker item from WebSocket
  /// Implements rate limiting: max 1 update per symbol per 2 seconds
  void addTickerItem(TickerItem item) {
    final now = DateTime.now();
    final lastTime = _lastUpdateTime[item.symbol];
    
    // Rate limit: skip if updated within last 2 seconds
    if (lastTime != null && now.difference(lastTime).inSeconds < 2) {
      return;
    }

    // Remove old entry for same symbol if exists (keep list fresh)
    _ticker.removeWhere((t) => t.symbol == item.symbol);
    
    // Add new item at front (newest first)
    _ticker.insert(0, item);
    
    // Keep only last 50 items to avoid memory bloat
    if (_ticker.length > 50) {
      _ticker.removeRange(50, _ticker.length);
    }

    _lastUpdateTime[item.symbol] = now;
    _error = null;
    notifyListeners();
  }

  /// Add multiple ticker items at once (from WebSocket batch)
  void addTickerItems(List<TickerItem> items) {
    for (final item in items) {
      addTickerItem(item);
    }
  }

  /// Set connection status
  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  /// Set error message
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear all ticker items
  void clear() {
    _ticker.clear();
    _lastUpdateTime.clear();
    notifyListeners();
  }

  /// Get ticker items for specific symbol
  List<TickerItem> getSymbolItems(String symbol) {
    return _ticker.where((item) => item.symbol == symbol).toList();
  }
}

/// DoggoSentimentProvider manages the "Doggo Sent of the Market" widget
/// Stores market sentiment summary data
class DoggoSentimentProvider extends ChangeNotifier {
  DoggoSentiment? _sentiment;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  DoggoSentiment? get sentiment => _sentiment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetch => _lastFetch;

  /// Update sentiment data
  /// Only refreshes if cache is older than 10 minutes
  Future<void> fetchSentiment() async {
    // Check if we should refresh (cache older than 10 minutes)
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 10) {
      return; // Use cached data
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Call API endpoint /market/sentiment-summary
      // For now, use static data for MVP
      _sentiment = DoggoSentiment(
        timestamp: DateTime.now(),
        bullishCount: 245,
        bearishCount: 89,
        neutralCount: 156,
        bullishPercentage: 55.8,
        bearishPercentage: 20.2,
        neutralPercentage: 35.4,
        topBullishSymbols: [
          TopSymbol(
            symbol: 'NVDA',
            count: 42,
            sentimentScore: 0.82,
            confidence: 0.91,
            sourceMix: 'reddit (25) + news (17)',
          ),
          TopSymbol(
            symbol: 'AAPL',
            count: 38,
            sentimentScore: 0.78,
            confidence: 0.88,
            sourceMix: 'reddit (22) + news (16)',
          ),
        ],
        topBearishSymbols: [
          TopSymbol(
            symbol: 'F',
            count: 15,
            sentimentScore: -0.79,
            confidence: 0.85,
            sourceMix: 'news (10) + reddit (5)',
          ),
        ],
        sentimentTrend24h: List.generate(
          24,
          (i) => HourlyTrend(
            hour: i,
            bullishPercentage: 45 + (i % 6) * 2.0, // Mock trend
          ),
        ),
        lastUpdate: DateTime.now(),
      );
      _lastFetch = DateTime.now();
    } catch (e) {
      _error = e.toString();
      print('Error fetching sentiment: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually set sentiment data (for testing or manual updates)
  void setSentiment(DoggoSentiment sentiment) {
    _sentiment = sentiment;
    _lastFetch = DateTime.now();
    _error = null;
    notifyListeners();
  }

  /// Refresh sentiment data (ignore cache)
  Future<void> refresh() async {
    _lastFetch = null; // Clear cache to force refresh
    await fetchSentiment();
  }

  /// Clear cached data
  void clear() {
    _sentiment = null;
    _lastFetch = null;
    _error = null;
    notifyListeners();
  }
}

/// NewsWithSummaryProvider manages news items with LLM-generated summaries
/// Caches summaries to avoid repeated API calls
class NewsWithSummaryProvider extends ChangeNotifier {
  final Map<String, NewsWithSummary> _newsCache = {};

  Map<String, NewsWithSummary> get newsCache => Map.unmodifiable(_newsCache);

  /// Get cached news summary or return loading state
  NewsWithSummary getOrCreate(String newsId, dynamic baseNewsItem) {
    if (_newsCache.containsKey(newsId)) {
      return _newsCache[newsId]!;
    }

    // Create entry with loading state
    final item = NewsWithSummary.fromNewsItem(baseNewsItem);
    _newsCache[newsId] = item;
    return item;
  }

  /// Update news item with summary
  void updateSummary(String newsId, List<String> bullets) {
    if (_newsCache.containsKey(newsId)) {
      _newsCache[newsId] = _newsCache[newsId]!.copyWith(
        summaryBullets: bullets,
        isLoadingSummary: false,
      );
      notifyListeners();
    }
  }

  /// Update news item with error
  void setSummaryError(String newsId, String error) {
    if (_newsCache.containsKey(newsId)) {
      _newsCache[newsId] = _newsCache[newsId]!.copyWith(
        isLoadingSummary: false,
        summaryError: error,
      );
      notifyListeners();
    }
  }

  /// Mark news item as loading summary
  void setLoading(String newsId) {
    if (_newsCache.containsKey(newsId)) {
      _newsCache[newsId] = _newsCache[newsId]!.copyWith(
        isLoadingSummary: true,
        summaryError: null,
      );
      notifyListeners();
    }
  }

  /// Clear cache
  void clear() {
    _newsCache.clear();
    notifyListeners();
  }
}

/// RouteProvider tracks current page/route context
/// Used by sidebar and other context-aware widgets
class RouteProvider extends ChangeNotifier {
  String _currentRoute = '/';
  String? _currentSymbol; // For stock detail pages
  Map<String, dynamic> _routeData = {};

  String get currentRoute => _currentRoute;
  String? get currentSymbol => _currentSymbol;
  Map<String, dynamic> get routeData => Map.unmodifiable(_routeData);

  void setRoute(String route, {String? symbol, Map<String, dynamic>? data}) {
    _currentRoute = route;
    _currentSymbol = symbol;
    _routeData = data ?? {};
    notifyListeners();
  }

  void clearSymbol() {
    _currentSymbol = null;
    notifyListeners();
  }
}

/// MetricExplanationCache provides caching for metric explanations
/// Avoids repeated Gemini API calls for same metrics
class MetricExplanationProvider extends ChangeNotifier {
  final Map<String, String> _cache = {};

  String? getExplanation(String metricName) {
    return _cache[metricName.toLowerCase()];
  }

  void setExplanation(String metricName, String explanation) {
    _cache[metricName.toLowerCase()] = explanation;
    notifyListeners();
  }

  bool hasExplanation(String metricName) {
    return _cache.containsKey(metricName.toLowerCase());
  }

  void clear() {
    _cache.clear();
    notifyListeners();
  }

  int getCacheSize() => _cache.length;
}
