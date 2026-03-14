import 'dart:convert';

import 'package:Dogonomics/backend/api_client.dart';
import 'package:Dogonomics/backend/api_config.dart';

class CompanyProfile {
  final String symbol;
  final String name;
  final String logo;
  final String description;
  final String exchange;
  final String website;

  CompanyProfile({
    required this.symbol,
    required this.name,
    required this.logo,
    required this.description,
    required this.exchange,
    required this.website,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      description: json['description'] ?? '',
      exchange: json['exchange'] ?? '',
      website: json['website'] ?? '',
    );
  }
}


class StockData {
  final String companyName;
  final double currentPrice;
  final double changePercentage;
  final String exchange;
  final String symbol;
  final double peRatio;
  final double eps;
  final String aboutDescription;
  final List<ChartDataPoint> chartData;

  StockData({
    required this.companyName,
    required this.currentPrice,
    required this.changePercentage,
    required this.exchange,
    required this.symbol,
    required this.peRatio,
    required this.eps,
    required this.aboutDescription,
    required this.chartData,
  });

  factory StockData.fromJson(Map<String, dynamic> json) {
    List<ChartDataPoint> chartPoints = [];
    if (json['chartData'] != null) {
      chartPoints = (json['chartData'] as List)
          .asMap()
          .entries
          .map((entry) => ChartDataPoint(
                x: entry.key.toDouble(),
                y: entry.value['close']?.toDouble() ?? 0.0,
              ))
          .toList();
    }

    return StockData(
      companyName: json['companyName'] ?? 'Unknown Company',
      currentPrice: json['currentPrice']?.toDouble() ?? 0.0,
      changePercentage: json['changePercentage']?.toDouble() ?? 0.0,
      exchange: json['exchange'] ?? 'Unknown',
      symbol: json['symbol'] ?? '',
      peRatio: json['peRatio']?.toDouble() ?? 0.0,
      eps: json['eps']?.toDouble() ?? 0.0,
      aboutDescription: json['aboutDescription'] ?? 'No description available',
      chartData: chartPoints,
    );
  }
}

class SentimentData {
  final String symbol;
  final double overallSentiment;
  final double confidence;
  final int newsCount;
  final double positiveRatio;
  final double negativeRatio;
  final double neutralRatio;
  final String recommendation;
  final List<NewsItem> newsItems;

  SentimentData({
    required this.symbol,
    required this.overallSentiment,
    required this.confidence,
    required this.newsCount,
    required this.positiveRatio,
    required this.negativeRatio,
    required this.neutralRatio,
    required this.recommendation,
    required this.newsItems,
  });

  factory SentimentData.fromJson(Map<String, dynamic> json) {
    List<NewsItem> news = [];
    if (json['news_items'] != null) {
      news = (json['news_items'] as List)
          .map((item) => NewsItem.fromJson(item))
          .toList();
    }

    final aggregate = json['aggregate_result'] ?? {};
    
    return SentimentData(
      symbol: json['symbol'] ?? '',
      overallSentiment: aggregate['overall_sentiment']?.toDouble() ?? 0.0,
      confidence: aggregate['confidence']?.toDouble() ?? 0.0,
      newsCount: aggregate['news_count']?.toInt() ?? 0,
      positiveRatio: aggregate['positive_ratio']?.toDouble() ?? 0.0,
      negativeRatio: aggregate['negative_ratio']?.toDouble() ?? 0.0,
      neutralRatio: aggregate['neutral_ratio']?.toDouble() ?? 0.0,
      recommendation: aggregate['recommendation'] ?? 'HOLD',
      newsItems: news,
    );
  }
}

class NewsItem {
  final String title;
  final String content;
  final String date;
  final BERTSentiment bertSentiment;
  // Additional fields for general market news
  final String description;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime? publishedAt;

  NewsItem({
    required this.title,
    required this.content,
    required this.date,
    required this.bertSentiment,
    this.description = '',
    this.source = '',
    this.url = '',
    this.imageUrl,
    this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? 'No title',
      content: json['content'] ?? 'No content',
      date: json['date'] ?? json['published_at'] ?? 'Unknown date',
      bertSentiment: BERTSentiment.fromJson(json['bert_sentiment'] ?? json['sentiment'] ?? {}),
      description: json['description'] ?? '',
      source: json['source'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['image_url'],
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
    );
  }
}

class BERTSentiment {
  final String label;
  final double confidence;
  final double score;

  BERTSentiment({
    required this.label,
    required this.confidence,
    required this.score,
  });

  factory BERTSentiment.fromJson(Map<String, dynamic> json) {
    return BERTSentiment(
      label: json['label'] ?? 'neutral',
      confidence: json['confidence']?.toDouble() ?? 0.0,
      score: json['score']?.toDouble() ?? 0.0,
    );
  }
}

class ChartDataPoint {
  final double x;
  final double y;

  ChartDataPoint({required this.x, required this.y});
}

// Quote Data Model
class QuoteData {
  final double currentPrice;
  final double change;
  final double percentChange;
  final double highPrice;
  final double lowPrice;
  final double openPrice;
  final double previousClose;
  final int timestamp;

  QuoteData({
    required this.currentPrice,
    required this.change,
    required this.percentChange,
    required this.highPrice,
    required this.lowPrice,
    required this.openPrice,
    required this.previousClose,
    required this.timestamp,
  });

  factory QuoteData.fromJson(Map<String, dynamic> json) {
    return QuoteData(
      currentPrice: json['c']?.toDouble() ?? 0.0,
      change: json['d']?.toDouble() ?? 0.0,
      percentChange: json['dp']?.toDouble() ?? 0.0,
      highPrice: json['h']?.toDouble() ?? 0.0,
      lowPrice: json['l']?.toDouble() ?? 0.0,
      openPrice: json['o']?.toDouble() ?? 0.0,
      previousClose: json['pc']?.toDouble() ?? 0.0,
      timestamp: json['t']?.toInt() ?? 0,
    );
  }
}

// Commodities Data Models
class CommodityData {
  final String name;
  final String interval;
  final String unit;
  final List<CommodityDataPoint> data;

  CommodityData({
    required this.name,
    required this.interval,
    required this.unit,
    required this.data,
  });

  factory CommodityData.fromJson(Map<String, dynamic> json) {
    List<CommodityDataPoint> dataPoints = [];
    if (json['data'] != null) {
      dataPoints = (json['data'] as List)
          .map((item) => CommodityDataPoint.fromJson(item))
          .toList();
    }

    return CommodityData(
      name: json['name'] ?? '',
      interval: json['interval'] ?? '',
      unit: json['unit'] ?? '',
      data: dataPoints,
    );
  }
}

class CommodityDataPoint {
  final String date;
  final String value;

  CommodityDataPoint({
    required this.date,
    required this.value,
  });

  factory CommodityDataPoint.fromJson(Map<String, dynamic> json) {
    return CommodityDataPoint(
      date: json['date'] ?? '',
      value: json['value'] ?? '0',
    );
  }
}

// Treasury Data Models
class YieldCurveData {
  final List<YieldCurveItem> data;

  YieldCurveData({required this.data});

  factory YieldCurveData.fromJson(Map<String, dynamic> json) {
    List<YieldCurveItem> items = [];
    if (json['data'] != null) {
      items = (json['data'] as List)
          .map((item) => YieldCurveItem.fromJson(item))
          .toList();
    }

    return YieldCurveData(data: items);
  }
}

class YieldCurveItem {
  final String recordDate;
  final String? securityDesc;
  final String? avgInterestRateAmt;

  YieldCurveItem({
    required this.recordDate,
    this.securityDesc,
    this.avgInterestRateAmt,
  });

  factory YieldCurveItem.fromJson(Map<String, dynamic> json) {
    return YieldCurveItem(
      recordDate: json['record_date'] ?? '',
      securityDesc: json['security_desc'],
      avgInterestRateAmt: json['avg_interest_rate_amt'],
    );
  }
}

class TreasuryRatesData {
  final List<TreasuryRateItem> data;

  TreasuryRatesData({required this.data});

  factory TreasuryRatesData.fromJson(Map<String, dynamic> json) {
    List<TreasuryRateItem> items = [];
    if (json['data'] != null) {
      items = (json['data'] as List)
          .map((item) => TreasuryRateItem.fromJson(item))
          .toList();
    }

    return TreasuryRatesData(data: items);
  }
}

class TreasuryRateItem {
  final String recordDate;
  final String? avgInterestRateAmt;

  TreasuryRateItem({
    required this.recordDate,
    this.avgInterestRateAmt,
  });

  factory TreasuryRateItem.fromJson(Map<String, dynamic> json) {
    return TreasuryRateItem(
      recordDate: json['record_date'] ?? '',
      avgInterestRateAmt: json['avg_interest_rate_amt'],
    );
  }
}

class PublicDebtData {
  final List<PublicDebtItem> data;

  PublicDebtData({required this.data});

  factory PublicDebtData.fromJson(Map<String, dynamic> json) {
    List<PublicDebtItem> items = [];
    if (json['data'] != null) {
      items = (json['data'] as List)
          .map((item) => PublicDebtItem.fromJson(item))
          .toList();
    }

    return PublicDebtData(data: items);
  }
}

class PublicDebtItem {
  final String recordDate;
  final String? totPubDebtOutAmt;

  PublicDebtItem({
    required this.recordDate,
    this.totPubDebtOutAmt,
  });

  factory PublicDebtItem.fromJson(Map<String, dynamic> json) {
    return PublicDebtItem(
      recordDate: json['record_date'] ?? '',
      totPubDebtOutAmt: json['tot_pub_debt_out_amt'],
    );
  }
}

// ─────────────────────────────────────────────
//  New Models for newly integrated endpoints
// ─────────────────────────────────────────────

/// Historical OHLCV data point from /chart/:symbol
class HistoricalDataPoint {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  HistoricalDataPoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory HistoricalDataPoint.fromJson(Map<String, dynamic> json) {
    return HistoricalDataPoint(
      date: json['date'] ?? json['t'] ?? '',
      open: (json['open'] ?? json['o'] ?? 0).toDouble(),
      high: (json['high'] ?? json['h'] ?? 0).toDouble(),
      low: (json['low'] ?? json['l'] ?? 0).toDouble(),
      close: (json['close'] ?? json['c'] ?? 0).toDouble(),
      volume: (json['volume'] ?? json['v'] ?? 0).toInt(),
    );
  }
}

/// Sentiment history entry from /db/sentiment/history/:symbol
class SentimentHistoryItem {
  final String symbol;
  final String timestamp;
  final double sentimentScore;
  final double confidence;
  final String label;

  SentimentHistoryItem({
    required this.symbol,
    required this.timestamp,
    required this.sentimentScore,
    required this.confidence,
    required this.label,
  });

  factory SentimentHistoryItem.fromJson(Map<String, dynamic> json) {
    return SentimentHistoryItem(
      symbol: json['symbol'] ?? '',
      timestamp: json['timestamp'] ?? json['time'] ?? '',
      sentimentScore: (json['sentiment_score'] ?? json['score'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      label: json['label'] ?? 'neutral',
    );
  }
}

/// Sentiment trend entry from /db/sentiment/trend/:symbol
class SentimentTrendItem {
  final String date;
  final double avgScore;
  final double avgConfidence;
  final int count;

  SentimentTrendItem({
    required this.date,
    required this.avgScore,
    required this.avgConfidence,
    required this.count,
  });

  factory SentimentTrendItem.fromJson(Map<String, dynamic> json) {
    return SentimentTrendItem(
      date: json['date'] ?? json['bucket'] ?? '',
      avgScore: (json['avg_score'] ?? json['avg_sentiment_score'] ?? 0).toDouble(),
      avgConfidence: (json['avg_confidence'] ?? 0).toDouble(),
      count: (json['count'] ?? json['total_analyses'] ?? 0).toInt(),
    );
  }
}

/// Daily sentiment summary from /db/sentiment/daily/:symbol
class DailySentimentSummary {
  final String date;
  final int totalAnalyses;
  final double avgSentimentScore;
  final double avgConfidence;
  final int positiveCount;
  final int neutralCount;
  final int negativeCount;

  DailySentimentSummary({
    required this.date,
    required this.totalAnalyses,
    required this.avgSentimentScore,
    required this.avgConfidence,
    required this.positiveCount,
    required this.neutralCount,
    required this.negativeCount,
  });

  factory DailySentimentSummary.fromJson(Map<String, dynamic> json) {
    return DailySentimentSummary(
      date: json['date'] ?? json['bucket'] ?? '',
      totalAnalyses: (json['total_analyses'] ?? 0).toInt(),
      avgSentimentScore: (json['avg_sentiment_score'] ?? 0).toDouble(),
      avgConfidence: (json['avg_confidence'] ?? 0).toDouble(),
      positiveCount: (json['positive_count'] ?? 0).toInt(),
      neutralCount: (json['neutral_count'] ?? 0).toInt(),
      negativeCount: (json['negative_count'] ?? 0).toInt(),
    );
  }
}

/// News article with BERT sentiment from /news/general/sentiment
class NewsArticleWithSentiment {
  final String title;
  final String description;
  final String url;
  final String source;
  final String publishedAt;
  final BERTSentiment? sentiment;

  NewsArticleWithSentiment({
    required this.title,
    required this.description,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.sentiment,
  });

  factory NewsArticleWithSentiment.fromJson(Map<String, dynamic> json) {
    BERTSentiment? sent;
    if (json['sentiment'] != null) {
      sent = BERTSentiment.fromJson(json['sentiment']);
    }
    return NewsArticleWithSentiment(
      title: json['title'] ?? '',
      description: json['description'] ?? json['content'] ?? '',
      url: json['url'] ?? '',
      source: json['source'] ?? '',
      publishedAt: json['published_at'] ?? json['publishedAt'] ?? '',
      sentiment: sent,
    );
  }
}

/// Aggregate sentiment from /news/general/sentiment
class AggregateSentiment {
  final double averageScore;
  final double averageConfidence;
  final Map<String, int> sentimentCounts;

  AggregateSentiment({
    required this.averageScore,
    required this.averageConfidence,
    required this.sentimentCounts,
  });

  factory AggregateSentiment.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    if (json['sentiment_counts'] != null) {
      (json['sentiment_counts'] as Map<String, dynamic>).forEach((k, v) {
        counts[k] = (v as num).toInt();
      });
    }
    return AggregateSentiment(
      averageScore: (json['average_score'] ?? 0).toDouble(),
      averageConfidence: (json['average_confidence'] ?? 0).toDouble(),
      sentimentCounts: counts,
    );
  }
}

/// Response from /news/general/sentiment
class NewsWithSentimentResponse {
  final String category;
  final int count;
  final AggregateSentiment aggregateSentiment;
  final List<NewsArticleWithSentiment> articles;

  NewsWithSentimentResponse({
    required this.category,
    required this.count,
    required this.aggregateSentiment,
    required this.articles,
  });

  factory NewsWithSentimentResponse.fromJson(Map<String, dynamic> json) {
    return NewsWithSentimentResponse(
      category: json['category'] ?? 'general',
      count: json['count'] ?? 0,
      aggregateSentiment: AggregateSentiment.fromJson(json['aggregate_sentiment'] ?? {}),
      articles: (json['articles'] as List? ?? [])
          .map((a) => NewsArticleWithSentiment.fromJson(a))
          .toList(),
    );
  }
}

/// API request log from /db/requests/recent
class ApiRequestLog {
  final String endpoint;
  final String method;
  final String? symbol;
  final int statusCode;
  final double responseTime;
  final String userAgent;
  final String timestamp;

  ApiRequestLog({
    required this.endpoint,
    required this.method,
    this.symbol,
    required this.statusCode,
    required this.responseTime,
    required this.userAgent,
    required this.timestamp,
  });

  factory ApiRequestLog.fromJson(Map<String, dynamic> json) {
    return ApiRequestLog(
      endpoint: json['endpoint'] ?? '',
      method: json['method'] ?? 'GET',
      symbol: json['symbol'],
      statusCode: json['status_code'] ?? 0,
      responseTime: (json['response_time_ms'] ?? json['response_time'] ?? 0).toDouble(),
      userAgent: json['user_agent'] ?? '',
      timestamp: json['timestamp'] ?? json['time'] ?? '',
    );
  }
}

/// Symbol request count from /db/requests/by-symbol
class SymbolRequestCount {
  final String symbol;
  final int count;

  SymbolRequestCount({required this.symbol, required this.count});

  factory SymbolRequestCount.fromJson(Map<String, dynamic> json) {
    return SymbolRequestCount(
      symbol: json['symbol'] ?? '',
      count: (json['count'] ?? json['request_count'] ?? 0).toInt(),
    );
  }
}
// ── Forex Models ──

class ForexPair {
  final String symbol;
  final double rate;
  final String pair;

  ForexPair({required this.symbol, required this.rate, required this.pair});

  factory ForexPair.fromJson(Map<String, dynamic> json) {
    return ForexPair(
      symbol: json['symbol'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      pair: json['pair'] ?? '',
    );
  }
}

class ForexRatesResponse {
  final String base;
  final int count;
  final List<ForexPair> rates;

  ForexRatesResponse({required this.base, required this.count, required this.rates});

  factory ForexRatesResponse.fromJson(Map<String, dynamic> json) {
    return ForexRatesResponse(
      base: json['base'] ?? 'USD',
      count: json['count'] ?? 0,
      rates: (json['rates'] as List?)?.map((e) => ForexPair.fromJson(e)).toList() ?? [],
    );
  }
}

// ── Crypto Models ──

class CryptoQuote {
  final String symbol;
  final String displaySymbol;
  final String name;
  final double price;
  final double high24h;
  final double low24h;
  final double open;
  final double volume;
  final double change;
  final double changePercent;

  CryptoQuote({
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.price,
    required this.high24h,
    required this.low24h,
    required this.open,
    required this.volume,
    required this.change,
    required this.changePercent,
  });

  factory CryptoQuote.fromJson(Map<String, dynamic> json) {
    return CryptoQuote(
      symbol: json['symbol'] ?? '',
      displaySymbol: json['display_symbol'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      high24h: (json['high_24h'] ?? 0).toDouble(),
      low24h: (json['low_24h'] ?? 0).toDouble(),
      open: (json['open'] ?? 0).toDouble(),
      volume: (json['volume'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['change_percent'] ?? 0).toDouble(),
    );
  }
}

class CryptoQuotesResponse {
  final String exchange;
  final int count;
  final List<CryptoQuote> quotes;

  CryptoQuotesResponse({required this.exchange, required this.count, required this.quotes});

  factory CryptoQuotesResponse.fromJson(Map<String, dynamic> json) {
    return CryptoQuotesResponse(
      exchange: json['exchange'] ?? 'binance',
      count: json['count'] ?? 0,
      quotes: (json['quotes'] as List?)?.map((e) => CryptoQuote.fromJson(e)).toList() ?? [],
    );
  }
}

// ── Social Sentiment Models ──

class SocialSentimentArticle {
  final String title;
  final String description;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime? publishedAt;
  final BERTSentiment? sentiment;

  SocialSentimentArticle({
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    this.imageUrl,
    this.publishedAt,
    this.sentiment,
  });

  factory SocialSentimentArticle.fromJson(Map<String, dynamic> json) {
    return SocialSentimentArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      source: json['source'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['image_url'],
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at']) : null,
      sentiment: json['sentiment'] != null ? BERTSentiment.fromJson(json['sentiment']) : null,
    );
  }
}

class SocialSentimentResponse {
  final String symbol;
  final int articlesCount;
  final String overallLabel;
  final double averageScore;
  final double averageConfidence;
  final Map<String, int> sentimentCounts;
  final List<SocialSentimentArticle> articles;

  SocialSentimentResponse({
    required this.symbol,
    required this.articlesCount,
    required this.overallLabel,
    required this.averageScore,
    required this.averageConfidence,
    required this.sentimentCounts,
    required this.articles,
  });

  factory SocialSentimentResponse.fromJson(Map<String, dynamic> json) {
    final aggregate = json['aggregate'] as Map<String, dynamic>? ?? {};
    final countsRaw = aggregate['sentiment_counts'] as Map<String, dynamic>? ?? {};
    return SocialSentimentResponse(
      symbol: json['symbol'] ?? '',
      articlesCount: json['articles_count'] ?? 0,
      overallLabel: aggregate['label'] ?? 'neutral',
      averageScore: (aggregate['average_score'] ?? 0).toDouble(),
      averageConfidence: (aggregate['average_confidence'] ?? 0).toDouble(),
      sentimentCounts: countsRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      articles: (json['articles'] as List?)
              ?.map((e) => SocialSentimentArticle.fromJson(e))
              .toList() ??
          [],
    );
  }
}

// ── Financial Indicators Models ──

class TechnicalIndicatorData {
  final String name;
  final double value;
  final String signal; // BUY, SELL, HOLD

  TechnicalIndicatorData({required this.name, required this.value, required this.signal});

  factory TechnicalIndicatorData.fromJson(Map<String, dynamic> json) {
    return TechnicalIndicatorData(
      name: json['name'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      signal: json['signal'] ?? 'HOLD',
    );
  }
}

class FinancialIndicatorsResponse {
  final String symbol;
  final double currentPrice;
  final double change;
  final double changePercent;
  final Map<String, dynamic> keyMetrics;
  final List<TechnicalIndicatorData> technicalIndicators;

  FinancialIndicatorsResponse({
    required this.symbol,
    required this.currentPrice,
    required this.change,
    required this.changePercent,
    required this.keyMetrics,
    required this.technicalIndicators,
  });

  factory FinancialIndicatorsResponse.fromJson(Map<String, dynamic> json) {
    return FinancialIndicatorsResponse(
      symbol: json['symbol'] ?? '',
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['change_percent'] ?? 0).toDouble(),
      keyMetrics: json['key_metrics'] as Map<String, dynamic>? ?? {},
      technicalIndicators: (json['technical_indicators'] as List?)
          ?.map((e) => TechnicalIndicatorData.fromJson(e))
          .toList() ?? [],
    );
  }
}

// ── Dogonomics Advice Models ──

class AdviceComponent {
  final String name;
  final double score;
  final double weight;
  final String signal;
  final String details;

  AdviceComponent({
    required this.name,
    required this.score,
    required this.weight,
    required this.signal,
    required this.details,
  });

  factory AdviceComponent.fromJson(Map<String, dynamic> json) {
    return AdviceComponent(
      name: json['name'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      weight: (json['weight'] ?? 0).toDouble(),
      signal: json['signal'] ?? 'HOLD',
      details: json['details'] ?? '',
    );
  }
}

class DogonomicsAdviceResponse {
  final String symbol;
  final String recommendation;
  final double score;
  final double confidence;
  final double currentPrice;
  final double changePercent;
  final List<AdviceComponent> components;
  final int dataPoints;

  DogonomicsAdviceResponse({
    required this.symbol,
    required this.recommendation,
    required this.score,
    required this.confidence,
    required this.currentPrice,
    required this.changePercent,
    required this.components,
    required this.dataPoints,
  });

  factory DogonomicsAdviceResponse.fromJson(Map<String, dynamic> json) {
    return DogonomicsAdviceResponse(
      symbol: json['symbol'] ?? '',
      recommendation: json['recommendation'] ?? 'HOLD',
      score: (json['score'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      currentPrice: (json['current_price'] ?? 0).toDouble(),
      changePercent: (json['change_percent'] ?? 0).toDouble(),
      components: (json['components'] as List?)
          ?.map((e) => AdviceComponent.fromJson(e))
          .toList() ?? [],
      dataPoints: json['data_points'] ?? 0,
    );
  }
}

class DogonomicsAPI {
  // ── Existing Endpoints (now using authenticated ApiClient) ──

  static Future<StockData> fetchStockData(String symbol) async {
    try {
      final response = await ApiClient.get('/stock/$symbol');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StockData.fromJson(data);
      } else {
        throw Exception('Failed to load stock data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<SentimentData> fetchSentimentData(String symbol) async {
    try {
      final response = await ApiClient.get(
        '/finnewsBert/$symbol',
        timeout: ApiConfig.longTimeout,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SentimentData.fromJson(data);
      } else {
        throw Exception('Failed to load sentiment data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sentiment analysis error: $e');
    }
  }

  static Future<CompanyProfile?> getCompanyProfile(String symbol) async {
    try {
      final response = await ApiClient.get('/profile/$symbol');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CompanyProfile.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Quote API
  static Future<QuoteData> fetchQuote(String symbol) async {
    try {
      final response = await ApiClient.get('/quote/$symbol');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return QuoteData.fromJson(data);
      } else {
        throw Exception('Failed to load quote: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Quote error: $e');
    }
  }

  // Commodities APIs
  static Future<CommodityData> fetchCommodityData(String category, {String? subtype}) async {
    try {
      String path = '/commodities/$category';
      if (subtype != null && subtype.isNotEmpty) {
        if (category == 'oil') {
          path += '?type=$subtype';
        } else if (category == 'metals') {
          path += '?metal=$subtype';
        } else if (category == 'agriculture') {
          path += '?commodity=$subtype';
        }
      }

      final response = await ApiClient.get(path);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CommodityData.fromJson(data);
      } else {
        throw Exception('Failed to load commodity data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Commodity data error: $e');
    }
  }

  // Treasury APIs
  static Future<YieldCurveData> fetchYieldCurve() async {
    try {
      final response = await ApiClient.get('/treasury/yield-curve');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return YieldCurveData.fromJson(data);
      } else {
        throw Exception('Failed to load yield curve: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Yield curve error: $e');
    }
  }

  static Future<TreasuryRatesData> fetchTreasuryRates({int days = 30}) async {
    try {
      final response = await ApiClient.get('/treasury/rates?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TreasuryRatesData.fromJson(data);
      } else {
        throw Exception('Failed to load treasury rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Treasury rates error: $e');
    }
  }

  static Future<PublicDebtData> fetchPublicDebt({int days = 90}) async {
    try {
      final response = await ApiClient.get('/treasury/debt?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PublicDebtData.fromJson(data);
      } else {
        throw Exception('Failed to load public debt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Public debt error: $e');
    }
  }

  // News APIs
  static Future<List<NewsItem>> fetchNewsFeed({int limit = 50}) async {
    try {
      final response = await ApiClient.get('/news/general?limit=$limit');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseNewsList(data);
      } else {
        throw Exception('Failed to load news feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('News feed error: $e');
    }
  }

  static Future<List<NewsItem>> fetchNewsBySymbol(String symbol, {int limit = 100}) async {
    try {
      final response = await ApiClient.get('/news/symbol/$symbol?limit=$limit');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseNewsList(data);
      } else {
        throw Exception('Failed to load news for $symbol: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('News by symbol error: $e');
    }
  }

  // FinBERT Inference API
  static Future<BERTSentiment> runFinBertInference(String text) async {
    try {
      final response = await ApiClient.post(
        '/finbert/inference',
        body: {'text': text},
        timeout: ApiConfig.longTimeout,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BERTSentiment.fromJson(data);
      } else {
        throw Exception('FinBERT inference failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('FinBERT inference error: $e');
    }
  }

  // ── New Endpoints ──

  /// Fetch historical OHLCV chart data from Polygon.io via backend.
  static Future<List<HistoricalDataPoint>> fetchChartData(String symbol, {int days = 30}) async {
    try {
      final response = await ApiClient.get('/chart/$symbol?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((e) => HistoricalDataPoint.fromJson(e)).toList();
        } else if (data['results'] != null) {
          return (data['results'] as List).map((e) => HistoricalDataPoint.fromJson(e)).toList();
        } else if (data['data'] != null) {
          return (data['data'] as List).map((e) => HistoricalDataPoint.fromJson(e)).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load chart data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Chart data error: $e');
    }
  }

  /// Search news by keyword.
  static Future<List<NewsItem>> searchNews(String keyword, {int limit = 10}) async {
    try {
      final response = await ApiClient.get('/news/search?q=$keyword&limit=$limit');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['articles'] != null) {
          return (data['articles'] as List).map((e) => NewsItem.fromJson(e)).toList();
        }
        return _parseNewsList(data);
      } else {
        throw Exception('News search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('News search error: $e');
    }
  }

  /// Fetch general news with BERT sentiment analysis.
  static Future<NewsWithSentimentResponse> fetchNewsWithSentiment({
    String category = 'general',
    int limit = 5,
  }) async {
    try {
      final response = await ApiClient.get(
        '/news/general/sentiment?category=$category&limit=$limit',
        timeout: ApiConfig.longTimeout,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NewsWithSentimentResponse.fromJson(data);
      } else {
        throw Exception('News sentiment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('News sentiment error: $e');
    }
  }

  /// Fetch sentiment history for a symbol.
  static Future<List<SentimentHistoryItem>> fetchSentimentHistory(String symbol, {int days = 7}) async {
    try {
      final response = await ApiClient.get('/db/sentiment/history/$symbol?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final history = data['history'] as List? ?? [];
        return history.map((e) => SentimentHistoryItem.fromJson(e)).toList();
      } else {
        throw Exception('Sentiment history failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sentiment history error: $e');
    }
  }

  /// Fetch sentiment trend for a symbol.
  static Future<List<SentimentTrendItem>> fetchSentimentTrend(String symbol, {int days = 7}) async {
    try {
      final response = await ApiClient.get('/db/sentiment/trend/$symbol?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trend = data['trend'] as List? ?? [];
        return trend.map((e) => SentimentTrendItem.fromJson(e)).toList();
      } else {
        throw Exception('Sentiment trend failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sentiment trend error: $e');
    }
  }

  /// Fetch daily sentiment summary for a symbol.
  static Future<List<DailySentimentSummary>> fetchDailySentimentSummary(String symbol, {int days = 7}) async {
    try {
      final response = await ApiClient.get('/db/sentiment/daily/$symbol?days=$days');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final summary = data['summary'] as List? ?? [];
        return summary.map((e) => DailySentimentSummary.fromJson(e)).toList();
      } else {
        throw Exception('Daily sentiment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Daily sentiment error: $e');
    }
  }

  /// Fetch recent API requests (admin/analytics).
  static Future<List<ApiRequestLog>> fetchRecentRequests({int limit = 50}) async {
    try {
      final response = await ApiClient.get('/db/requests/recent?limit=$limit');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final requests = data['requests'] as List? ?? (data is List ? data : []);
        return (requests is List ? requests : [])
            .map((e) => ApiRequestLog.fromJson(e))
            .toList();
      } else {
        throw Exception('Recent requests failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Recent requests error: $e');
    }
  }

  /// Fetch requests grouped by symbol (admin/analytics).
  static Future<List<SymbolRequestCount>> fetchRequestsBySymbol() async {
    try {
      final response = await ApiClient.get('/db/requests/by-symbol');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['symbols'] as List? ?? (data is List ? data : []);
        return (items is List ? items : [])
            .map((e) => SymbolRequestCount.fromJson(e))
            .toList();
      } else {
        throw Exception('Requests by symbol failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Requests by symbol error: $e');
    }
  }

  // ── Forex Endpoints ──

  /// Fetch forex exchange rates relative to a base currency.
  static Future<ForexRatesResponse> fetchForexRates({String base = 'USD'}) async {
    try {
      final response = await ApiClient.get('/forex/rates?base=$base');
      if (response.statusCode == 200) {
        return ForexRatesResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Forex rates failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Forex rates error: $e');
    }
  }

  /// Fetch forex category news.
  static Future<List<NewsItem>> fetchForexNews({int limit = 20}) async {
    try {
      final response = await ApiClient.get('/news/general?category=forex&limit=$limit');
      if (response.statusCode == 200) {
        return _parseNewsList(json.decode(response.body));
      } else {
        throw Exception('Forex news failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Forex news error: $e');
    }
  }

  // ── Crypto Endpoints ──

  /// Fetch current quotes for popular crypto pairs.
  static Future<CryptoQuotesResponse> fetchCryptoQuotes() async {
    try {
      final response = await ApiClient.get('/crypto/quotes');
      if (response.statusCode == 200) {
        return CryptoQuotesResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Crypto quotes failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Crypto quotes error: $e');
    }
  }

  /// Fetch crypto category news.
  static Future<List<NewsItem>> fetchCryptoNews({int limit = 20}) async {
    try {
      final response = await ApiClient.get('/news/general?category=crypto&limit=$limit');
      if (response.statusCode == 200) {
        return _parseNewsList(json.decode(response.body));
      } else {
        throw Exception('Crypto news failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Crypto news error: $e');
    }
  }

  // ── Social Sentiment ──

  /// Fetch social sentiment analysis for a symbol.
  static Future<SocialSentimentResponse> fetchSocialSentiment(String symbol, {int limit = 10}) async {
    try {
      final response = await ApiClient.get('/social/sentiment/$symbol?limit=$limit');
      if (response.statusCode == 200) {
        return SocialSentimentResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Social sentiment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Social sentiment error: $e');
    }
  }

  // ── Financial Indicators & Advice ──

  /// Fetch comprehensive financial indicators for a symbol.
  static Future<FinancialIndicatorsResponse> fetchFinancialIndicators(String symbol) async {
    try {
      final response = await ApiClient.get('/indicators/$symbol');
      if (response.statusCode == 200) {
        return FinancialIndicatorsResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Indicators failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Indicators error: $e');
    }
  }

  /// Fetch aggregate Dogonomics advice for a symbol.
  static Future<DogonomicsAdviceResponse> fetchDogonomicsAdvice(String symbol) async {
    try {
      final response = await ApiClient.get(
        '/advice/$symbol',
        timeout: const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        return DogonomicsAdviceResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Advice failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Advice error: $e');
    }
  }

  // ── Helpers ──

  static List<NewsItem> _parseNewsList(dynamic data) {
    if (data is List) {
      return data.map((e) => NewsItem.fromJson(e)).toList();
    } else if (data is Map<String, dynamic>) {
      for (final key in ['articles', 'data', 'news']) {
        if (data[key] != null && data[key] is List) {
          return (data[key] as List).map((e) => NewsItem.fromJson(e)).toList();
        }
      }
    }
    return [];
  }
}
