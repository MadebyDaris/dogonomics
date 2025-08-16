import 'package:fl_chart/fl_chart.dart' show LineChartBarData, FlBorderData, FlTitlesData, FlGridData, LineChartData, LineChart, BarAreaData, FlDotData, FlSpot;
import 'package:flutter/material.dart';

import '../backend/dogonomicsApi.dart';

// Important Company information
class CompanyHeader extends StatelessWidget {
  final StockData stockData;

  const CompanyHeader({Key? key, required this.stockData}) : super(key: key);

@override
Widget build(BuildContext context) {
  bool isPositive = stockData.changePercentage >= 0;
  
  return Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stockData.companyName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '\$${stockData.currentPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${stockData.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}

// Charts
class ChartWidget extends StatelessWidget {

  final List<ChartDataPoint> chartData;
  const ChartWidget({Key? key, required this.chartData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: const Center(
          child: Text(
            'Chart data not available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.y);
    }).toList();

    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KeyMetricsGrid extends StatelessWidget {
  final StockData stockData;

  const KeyMetricsGrid({Key? key, required this.stockData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metrics = [
      {'label': 'Symbol', 'value': stockData.symbol},
      {'label': 'Exchange', 'value': stockData.exchange},
      {'label': 'PE Ratio', 'value': stockData.peRatio.toStringAsFixed(2)},
      {'label': 'EPS', 'value': stockData.eps.toStringAsFixed(2)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return MetricCard(
          label: metric['label']!,
          value: metric['value']!,
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const MetricCard({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 14, 19, 28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyInfo extends StatelessWidget {
  final String aboutDescription;

  const CompanyInfo({Key? key, required this.aboutDescription}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            aboutDescription,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class SentimentOverview extends StatelessWidget {
  final SentimentData sentimentData;

  const SentimentOverview({Key? key, required this.sentimentData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color getRecommendationColor() {
      switch (sentimentData.recommendation.toUpperCase()) {
        case 'BUY':
          return Colors.green;
        case 'SELL':
          return Colors.red;
        case 'WEAK_BUY':
          return Colors.green[300]!;
        case 'WEAK_SELL':
          return Colors.red[300]!;
        default:
          return Colors.orange;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Sentiment',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    '${(sentimentData.overallSentiment * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: sentimentData.overallSentiment >= 0 ? Colors.green : Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: getRecommendationColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  sentimentData.recommendation.replaceAll('_', ' '),
                  style: TextStyle(
                    color: getRecommendationColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSentimentRatio('Positive', sentimentData.positiveRatio, Colors.green),
              _buildSentimentRatio('Neutral', sentimentData.neutralRatio, Colors.orange),
              _buildSentimentRatio('Negative', sentimentData.negativeRatio, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Based on ${sentimentData.newsCount} news articles',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentRatio(String label, double ratio, Color color) {
    return Column(
      children: [
        Text(
          '${(ratio * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class NewsList extends StatelessWidget {
  final List<NewsItem> news;

  const NewsList({Key? key, required this.news}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return const Center(
        child: Text(
          'No news articles available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: news.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: NewsCard(newsItem: item),
        );
      }).toList(),
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsItem newsItem;

  const NewsCard({Key? key, required this.newsItem}) : super(key: key);

  Color _getSentimentColor() {
    switch (newsItem.bertSentiment.label.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _getSentimentColor();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  newsItem.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  newsItem.bertSentiment.label.toUpperCase(),
                  style: TextStyle(
                    color: sentimentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                newsItem.date,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              Text(
                'Confidence: ${(newsItem.bertSentiment.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}