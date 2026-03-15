import 'package:fl_chart/fl_chart.dart' show LineChartBarData, FlBorderData, FlTitlesData, FlGridData, LineChartData, LineChart, BarAreaData, FlDotData, FlSpot;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/dogonomicsApi.dart';
import '../pages/newsArticleDetail.dart';
import '../widgets/infoTooltip.dart';
import '../widgets/explain_tooltip_widget.dart';
import '../utils/constant.dart';

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
          style: HEADING_LARGE,
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
                color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${stockData.changePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
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
          color: CARD_BACKGROUND,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BORDER_COLOR),
        ),
        child: Center(
          child: Text(
            'Chart data not available',
            style: BODY_SECONDARY,
          ),
        ),
      );
    }

    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.y);
    }).toList();

    // Determine if the trend is positive or negative
    final isPositive = chartData.last.y >= chartData.first.y;

    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Chart',
                style: HEADING_SMALL,
              ),
              const SizedBox(width: 6),
              ExplainTooltipWidget(
                metricName: 'Price Chart',
                metricValue: 'Trend overview',
                iconSize: 13,
              ),
              Row(
                children: [
                  InfoTooltip(
                    title: 'Price Chart',
                    message: 'This chart shows the stock\'s price movement over time. Technical analysis involves identifying patterns and trends to predict future price movements. Look for support/resistance levels, trend lines, and chart patterns like head and shoulders or double tops/bottoms.',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ACCENT_GREEN.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.zoom_in, size: 14, color: ACCENT_GREEN),
                        SizedBox(width: 4),
                        Text(
                          'Tap to expand',
                          style: TextStyle(
                            color: ACCENT_GREEN,
                            fontSize: 10,
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
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      {
        'label': 'Symbol',
        'value': stockData.symbol,
        'tooltip': 'The unique ticker symbol used to identify this stock on the exchange.',
      },
      {
        'label': 'Exchange',
        'value': stockData.exchange,
        'tooltip': 'The stock exchange where this security is traded (NYSE, NASDAQ, etc.).',
      },
      {
        'label': 'PE Ratio',
        'value': stockData.peRatio.toStringAsFixed(2),
        'tooltip': 'Price-to-Earnings Ratio: Shows how much investors are willing to pay per dollar of earnings. A higher P/E might indicate growth expectations, while a lower P/E could suggest undervaluation or slower growth.',
      },
      {
        'label': 'EPS',
        'value': stockData.eps.toStringAsFixed(2),
        'tooltip': 'Earnings Per Share: The portion of company\'s profit allocated to each outstanding share. Higher EPS indicates greater profitability. Formula: Net Income / Total Outstanding Shares.',
      },
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
          tooltip: metric['tooltip']!,
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String tooltip;

  const MetricCard({
    Key? key, 
    required this.label, 
    required this.value,
    required this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CAPTION_TEXT,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoTooltip(
                    title: label,
                    message: tooltip,
                  ),
                  const SizedBox(width: 4),
                  ExplainTooltipWidget(
                    metricName: label,
                    metricValue: value,
                    iconSize: 12,
                  ),
                ],
              ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CARD_BACKGROUND,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BORDER_COLOR),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'About',
                    style: HEADING_SMALL,
                  ),
                  InfoTooltip(
                    title: 'Company Information',
                    message: 'Understanding a company\'s business model, products, and market position is crucial for investment decisions. Read about their operations, competitive advantages, and growth strategies.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                aboutDescription,
                style: BODY_SECONDARY.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.lightbulb_outline,
          iconColor: COLOR_WARNING,
          title: 'Investment Tip: Fundamental Analysis',
          summary: 'Learn how to evaluate a company beyond the numbers',
          detailedInfo: '''
Fundamental analysis involves evaluating a company's intrinsic value by examining:

• Financial Statements: Review balance sheets, income statements, and cash flow statements
• Management Quality: Research the leadership team's track record and strategy
• Competitive Position: Analyze market share and competitive advantages
• Industry Trends: Understand sector dynamics and growth potential
• Economic Moat: Identify barriers that protect the company from competition

Key metrics to consider:
- Revenue and earnings growth trends
- Profit margins and return on equity (ROE)
- Debt-to-equity ratio for financial health
- Free cash flow generation
- Price-to-book (P/B) and price-to-sales (P/S) ratios

Remember: A good company at a fair price is better than a fair company at a good price!
          ''',
        ),
      ],
    );
  }
}

// New Company Profile Card widget
class CompanyProfileCard extends StatelessWidget {
  final CompanyProfile profile;

  const CompanyProfileCard({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CARD_BACKGROUND,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BORDER_COLOR),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Header with Logo
              Row(
                children: [
                  if (profile.logo.isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(profile.logo),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: HEADING_SMALL,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${profile.symbol} • ${profile.exchange}',
                              style: CAPTION_TEXT,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: BORDER_COLOR),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'About',
                style: HEADING_SMALL,
              ),
              const SizedBox(height: 8),
              Text(
                profile.description.isNotEmpty 
                  ? profile.description 
                  : 'No company description available.',
                style: BODY_SECONDARY.copyWith(height: 1.5),
              ),
              
              // Website
              if (profile.website.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(profile.website);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.language,
                        size: 16,
                        color: ACCENT_GREEN,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.website,
                          style: BODY_SECONDARY.copyWith(
                            color: ACCENT_GREEN,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.lightbulb_outline,
          iconColor: COLOR_WARNING,
          title: 'Investment Tip: Fundamental Analysis',
          summary: 'Learn how to evaluate a company beyond the numbers',
          detailedInfo: '''
Fundamental analysis involves evaluating a company's intrinsic value by examining:

• Financial Statements: Review balance sheets, income statements, and cash flow statements
• Management Quality: Research the leadership team's track record and strategy
• Competitive Position: Analyze market share and competitive advantages
• Industry Trends: Understand sector dynamics and growth potential
• Economic Moat: Identify barriers that protect the company from competition

Key metrics to consider:
- Revenue and earnings growth trends
- Profit margins and return on equity (ROE)
- Debt-to-equity ratio for financial health
- Free cash flow generation
- Price-to-book (P/B) and price-to-sales (P/S) ratios

Remember: A good company at a fair price is better than a fair company at a good price!
          ''',
        ),
      ],
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
          return COLOR_POSITIVE;
        case 'SELL':
          return COLOR_NEGATIVE;
        case 'WEAK_BUY':
          return COLOR_POSITIVE.withOpacity(0.7);
        case 'WEAK_SELL':
          return COLOR_NEGATIVE.withOpacity(0.7);
        default:
          return COLOR_WARNING;
      }
    }

    return Column(
      children: [
        QuickTipBanner(
          tip: 'Sentiment analysis uses AI to evaluate news articles and predict market sentiment. It\'s one tool among many for making informed decisions.',
          color: COLOR_INFO,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CARD_BACKGROUND,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BORDER_COLOR),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Overall Sentiment',
                            style: HEADING_SMALL,
                          ),
                          const SizedBox(width: 8),
                          InfoTooltip(
                            title: 'Sentiment Analysis',
                            message: 'Our AI analyzes news articles to gauge market sentiment. A positive sentiment (>0) suggests optimistic news, while negative sentiment (<0) indicates concerns. This is based on natural language processing of recent news articles.',
                          ),
                        ],
                      ),
                      Text(
                        '${(sentimentData.overallSentiment * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: sentimentData.overallSentiment >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
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
                  _buildSentimentRatio('Positive', sentimentData.positiveRatio, COLOR_POSITIVE),
                  _buildSentimentRatio('Neutral', sentimentData.neutralRatio, COLOR_WARNING),
                  _buildSentimentRatio('Negative', sentimentData.negativeRatio, COLOR_NEGATIVE),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Based on ${sentimentData.newsCount} news articles',
                style: CAPTION_TEXT,
              ),
            ],
          ),
        ),
      ],
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
          style: CAPTION_TEXT,
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
        return COLOR_POSITIVE;
      case 'negative':
        return COLOR_NEGATIVE;
      default:
        return TEXT_DISABLED;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _getSentimentColor();
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsArticleDetailPage(newsItem: newsItem),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CARD_BACKGROUND,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BORDER_COLOR),
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
                    style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
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
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: TEXT_SECONDARY,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      newsItem.date,
                      style: CAPTION_TEXT,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 14,
                      color: TEXT_SECONDARY,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(newsItem.bertSentiment.confidence * 100).toStringAsFixed(1)}% confident',
                      style: CAPTION_TEXT,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Read more',
                  style: BODY_SECONDARY.copyWith(
                    color: ACCENT_GREEN,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: ACCENT_GREEN,
                ),
              ],
            ),
          ],
        ),
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
      style: HEADING_MEDIUM,
    );
  }
}