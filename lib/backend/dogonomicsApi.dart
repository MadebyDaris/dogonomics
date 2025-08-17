import 'dart:convert';

import 'package:http/http.dart' as http;

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

  NewsItem({
    required this.title,
    required this.content,
    required this.date,
    required this.bertSentiment,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? 'No title',
      content: json['content'] ?? 'No content',
      date: json['date'] ?? 'Unknown date',
      bertSentiment: BERTSentiment.fromJson(json['bert_sentiment'] ?? {}),
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

class DogonomicsAPI {
  // NOTE: This IP address is for the Android emulator to connect to the host machine.
  // For other platforms, you may need to change this to the correct IP address.
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<StockData> fetchStockData(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stock/$symbol'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

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
      final response = await http.get(
        Uri.parse('$baseUrl/finnewsBert/$symbol'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60)); // Longer timeout for sentiment analysis

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
      final response = await http.get(
        Uri.parse('$baseUrl/profile/$symbol'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CompanyProfile.fromJson(data);
      } else {
        print('Failed to load company profile for $symbol: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading company profile for $symbol: $e');
      return null;
    }
  }
}
