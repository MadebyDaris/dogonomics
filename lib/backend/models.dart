/// Chat message model for storing conversation history
class ChatMessage {
  final String id;
  final String text;
  final String sender; // 'user' or 'assistant'
  final DateTime timestamp;
  final String? context; // Optional context: stock symbol, sentiment, etc.

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.context,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      sender: json['sender'] ?? 'user',
      timestamp: json['timestamp'] is DateTime 
          ? json['timestamp'] 
          : DateTime.parse(json['timestamp'] ?? '2026-01-01'),
      context: json['context'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'sender': sender,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
  };
}

/// Extended news item with LLM-generated summary and sentiment gauge
class NewsWithSummary {
  final String id;
  final String title;
  final String content;
  final String source;
  final DateTime date;
  final String? imageUrl;
  final List<String> summaryBullets; // 3 LLM-generated bullets
  final double sentimentScore; // -1 to 1 (FinBERT)
  final double sentimentConfidence; // 0 to 1
  final String sentimentLabel; // 'positive', 'negative', 'neutral'
  final bool isLoadingSummary;
  final String? summaryError;

  NewsWithSummary({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    required this.date,
    this.imageUrl,
    this.summaryBullets = const [],
    this.sentimentScore = 0.0,
    this.sentimentConfidence = 0.0,
    this.sentimentLabel = 'neutral',
    this.isLoadingSummary = false,
    this.summaryError,
  });

  factory NewsWithSummary.fromNewsItem(dynamic newsItem) {
    return NewsWithSummary(
      id: newsItem.id ?? '',
      title: newsItem.title ?? 'Untitled',
      content: newsItem.content ?? '',
      source: newsItem.source ?? 'Unknown',
      date: newsItem.date ?? DateTime.now(),
      imageUrl: newsItem.imageUrl,
      sentimentScore: newsItem.sentimentScore ?? 0.0,
      sentimentConfidence: newsItem.sentimentConfidence ?? 0.0,
      sentimentLabel: newsItem.sentimentLabel ?? 'neutral',
    );
  }

  NewsWithSummary copyWith({
    List<String>? summaryBullets,
    bool? isLoadingSummary,
    String? summaryError,
  }) {
    return NewsWithSummary(
      id: id,
      title: title,
      content: content,
      source: source,
      date: date,
      imageUrl: imageUrl,
      summaryBullets: summaryBullets ?? this.summaryBullets,
      sentimentScore: sentimentScore,
      sentimentConfidence: sentimentConfidence,
      sentimentLabel: sentimentLabel,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      summaryError: summaryError ?? this.summaryError,
    );
  }
}

/// Market sentiment item from WebSocket (/ws/market-sentiment)
class TickerItem {
  final String symbol;
  final String source; // 'reddit' or 'news'
  final String text; // Post title or article headline
  final String sentimentLabel; // 'positive', 'negative', 'neutral'
  final double confidence; // 0.0 to 1.0
  final double sentimentScore; // -1.0 to 1.0
  final DateTime timestamp;
  final String? url;
  final int? upvotes;
  final String? subredditOrSite;

  TickerItem({
    required this.symbol,
    required this.source,
    required this.text,
    required this.sentimentLabel,
    required this.confidence,
    required this.sentimentScore,
    required this.timestamp,
    this.url,
    this.upvotes,
    this.subredditOrSite,
  });

  factory TickerItem.fromJson(Map<String, dynamic> json) {
    return TickerItem(
      symbol: json['symbol'] ?? '',
      source: json['source'] ?? 'reddit',
      text: json['text'] ?? '',
      sentimentLabel: json['sentiment_label'] ?? 'neutral',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      sentimentScore: (json['sentiment_score'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp']
          : DateTime.parse(json['timestamp'] ?? '2026-01-01'),
      url: json['url'],
      upvotes: json['upvotes'],
      subredditOrSite: json['subreddit_or_site'],
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'source': source,
    'text': text,
    'sentiment_label': sentimentLabel,
    'confidence': confidence,
    'sentiment_score': sentimentScore,
    'timestamp': timestamp.toIso8601String(),
    'url': url,
    'upvotes': upvotes,
    'subreddit_or_site': subredditOrSite,
  };

  /// Color for UI based on sentiment
  String get sentimentColor {
    if (sentimentLabel == 'positive') return '#4CAF50'; // Green
    if (sentimentLabel == 'negative') return '#F44336'; // Red
    return '#9E9E9E'; // Gray for neutral
  }

  /// Source badge
  String get sourceBadge => source == 'reddit' ? 'R' : 'NEWS';
}

/// Market sentiment overview for "Doggo Sent of the Market" widget
class DoggoSentiment {
  final DateTime timestamp;
  final int bullishCount;
  final int bearishCount;
  final int neutralCount;
  final double bullishPercentage;
  final double bearishPercentage;
  final double neutralPercentage;
  final List<TopSymbol> topBullishSymbols;
  final List<TopSymbol> topBearishSymbols;
  final List<HourlyTrend> sentimentTrend24h;
  final DateTime lastUpdate;

  DoggoSentiment({
    required this.timestamp,
    required this.bullishCount,
    required this.bearishCount,
    required this.neutralCount,
    required this.bullishPercentage,
    required this.bearishPercentage,
    required this.neutralPercentage,
    required this.topBullishSymbols,
    required this.topBearishSymbols,
    required this.sentimentTrend24h,
    required this.lastUpdate,
  });

  factory DoggoSentiment.fromJson(Map<String, dynamic> json) {
    return DoggoSentiment(
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp']
          : DateTime.parse(json['timestamp'] ?? '2026-01-01'),
      bullishCount: json['overall_sentiment']?['bullish_count'] ?? 0,
      bearishCount: json['overall_sentiment']?['bearish_count'] ?? 0,
      neutralCount: json['overall_sentiment']?['neutral_count'] ?? 0,
      bullishPercentage: (json['overall_sentiment']?['bullish_percentage'] ?? 0).toDouble(),
      bearishPercentage: (json['overall_sentiment']?['bearish_percentage'] ?? 0).toDouble(),
      neutralPercentage: (json['overall_sentiment']?['neutral_percentage'] ?? 0).toDouble(),
      topBullishSymbols: (json['top_bullish_symbols'] as List?)
          ?.map((e) => TopSymbol.fromJson(e))
          .toList() ?? [],
      topBearishSymbols: (json['top_bearish_symbols'] as List?)
          ?.map((e) => TopSymbol.fromJson(e))
          .toList() ?? [],
      sentimentTrend24h: (json['sentiment_trend_24h'] as List?)
          ?.map((e) => HourlyTrend.fromJson(e))
          .toList() ?? [],
      lastUpdate: json['last_update'] is DateTime
          ? json['last_update']
          : DateTime.parse(json['last_update'] ?? '2026-01-01'),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'overall_sentiment': {
      'bullish_count': bullishCount,
      'bearish_count': bearishCount,
      'neutral_count': neutralCount,
      'bullish_percentage': bullishPercentage,
      'bearish_percentage': bearishPercentage,
      'neutral_percentage': neutralPercentage,
    },
    'top_bullish_symbols': topBullishSymbols.map((s) => s.toJson()).toList(),
    'top_bearish_symbols': topBearishSymbols.map((s) => s.toJson()).toList(),
    'sentiment_trend_24h': sentimentTrend24h.map((t) => t.toJson()).toList(),
    'last_update': lastUpdate.toIso8601String(),
  };

  /// Overall market trend
  String get overallTrend {
    if (bullishPercentage > 50) return 'Bullish';
    if (bearishPercentage > 50) return 'Bearish';
    return 'Neutral';
  }

  /// Color for trend indicator
  String get trendColor {
    if (bullishPercentage > 50) return '#4CAF50'; // Green
    if (bearishPercentage > 50) return '#F44336'; // Red
    return '#9E9E9E'; // Gray
  }
}

/// Top symbol in sentiment rankings
class TopSymbol {
  final String symbol;
  final int count; // bullish_count or bearish_count
  final double sentimentScore;
  final double confidence;
  final String sourceMix; // "reddit (25) + news (17)"

  TopSymbol({
    required this.symbol,
    required this.count,
    required this.sentimentScore,
    required this.confidence,
    required this.sourceMix,
  });

  factory TopSymbol.fromJson(Map<String, dynamic> json) {
    return TopSymbol(
      symbol: json['symbol'] ?? '',
      count: json['bullish_count'] ?? json['bearish_count'] ?? 0,
      sentimentScore: (json['sentiment_score'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      sourceMix: json['source_mix'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'count': count,
    'sentiment_score': sentimentScore,
    'confidence': confidence,
    'source_mix': sourceMix,
  };
}

/// Hourly sentiment trend data
class HourlyTrend {
  final int hour;
  final double bullishPercentage;

  HourlyTrend({
    required this.hour,
    required this.bullishPercentage,
  });

  factory HourlyTrend.fromJson(Map<String, dynamic> json) {
    return HourlyTrend(
      hour: json['hour'] ?? 0,
      bullishPercentage: (json['bullish_pct'] ?? json['bullish_percentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'bullish_pct': bullishPercentage,
  };
}
