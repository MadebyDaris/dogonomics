import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/widgets/stockDetailsWidgets.dart';
import 'package:Dogonomics/widgets/infoTooltip.dart';
import 'package:Dogonomics/pages/chartDetailPage.dart';
import 'package:Dogonomics/pages/newsFeedPage.dart';
import 'package:Dogonomics/backend/providers.dart';
import 'package:Dogonomics/widgets/doggo_sidebar_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../backend/dogonomicsApi.dart';

class StockDetailsPage extends StatefulWidget {
  final String symbol;

  const StockDetailsPage({Key? key, required this.symbol}) : super(key: key);


  @override
  _StockDetailsPageState createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RouteProvider _routeProvider = RouteProvider();
  final MetricExplanationProvider _explanationProvider = MetricExplanationProvider();
  StockData? stockData;
  SentimentData? sentimentData;
  CompanyProfile? companyProfile;
  List<SentimentTrendItem> sentimentTrend = [];
  List<DailySentimentSummary> dailySummary = [];
  bool isLoadingStock = true;
  bool isLoadingSentiment = true;
  bool isLoadingProfile = true;
  bool isLoadingHistory = true;
  String? stockError;
  String? sentimentError;
  String? profileError;
  String? historyError;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

    Future<void> _loadData() async {
    await Future.wait([
      _loadStockData(),
      _loadSentimentData(),
      _loadCompanyProfile(),
      _loadSentimentHistory(),
    ]);
  }
    Future<void> _loadStockData() async {
    try {
      final data = await DogonomicsAPI.fetchStockData(widget.symbol);
      if (mounted) {
        setState(() {
          stockData = data;
          isLoadingStock = false;
          stockError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStock = false;
          stockError = e.toString();
        });
      }
    }
  }

  Future<void> _loadSentimentData() async {
    try {
      final data = await DogonomicsAPI.fetchSentimentData(widget.symbol);
      if (mounted) {
        setState(() {
          sentimentData = data;
          isLoadingSentiment = false;
          sentimentError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingSentiment = false;
          sentimentError = e.toString();
        });
      }
    }
  }

  Future<void> _loadCompanyProfile() async {
    try {
      final profile = await DogonomicsAPI.getCompanyProfile(widget.symbol);
      if (mounted) {
        setState(() {
          companyProfile = profile;
          isLoadingProfile = false;
          profileError = profile == null ? 'Profile not available' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingProfile = false;
          profileError = e.toString();
        });
      }
    }
  }

  Future<void> _loadSentimentHistory() async {
    try {
      final results = await Future.wait([
        DogonomicsAPI.fetchSentimentTrend(widget.symbol, days: 14),
        DogonomicsAPI.fetchDailySentimentSummary(widget.symbol, days: 14),
      ]);
      if (mounted) {
        setState(() {
          sentimentTrend = results[0] as List<SentimentTrendItem>;
          dailySummary = results[1] as List<DailySentimentSummary>;
          isLoadingHistory = false;
          historyError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingHistory = false;
          historyError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: _buildAppBar(),
      body: SidebarScaffold(
        currentRoute: '/stock_details',
        currentSymbol: widget.symbol,
        routeProvider: _routeProvider,
        explanationProvider: _explanationProvider,
        contextData: {
          'price': stockData?.currentPrice,
          'sentiment': sentimentData?.overallSentiment,
        },
        body: Column(
          children: [
            if (isLoadingStock)
              Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: ACCENT_GREEN),
              )
            else if (stockError != null)
              _buildErrorWidget(stockError!)
            else if (stockData != null) ...[
              CompanyHeader(stockData: stockData!),
              if (stockData!.chartData.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChartDetailPage(
                          symbol: widget.symbol,
                          companyName: stockData!.companyName,
                          chartData: stockData!.chartData,
                        ),
                      ),
                    );
                  },
                  child: ChartWidget(chartData: stockData!.chartData),
                ),
            ],
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildSentimentTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
    PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: APP_BACKGROUND,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: TEXT_PRIMARY),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.symbol,
        style: HEADING_SMALL,
      ),
      centerTitle: true,
    );
  }

    Widget _buildOverviewTab() {
    if (stockData == null) {
      return Center(
        child: Text(
          'No stock data available',
          style: BODY_PRIMARY,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Key Metrics'),
          const SizedBox(height: 16),
          KeyMetricsGrid(stockData: stockData!),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Company Information'),
          const SizedBox(height: 16),
          if (isLoadingProfile)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: ACCENT_GREEN),
              ),
            )
          else if (companyProfile != null)
            CompanyProfileCard(profile: companyProfile!)
          else
            CompanyInfo(aboutDescription: stockData!.aboutDescription),
        ],
      ),
    );
  }

  Widget _buildSentimentTab() {
    if (isLoadingSentiment) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights_outlined, size: 44, color: ACCENT_GREEN_LIGHT),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: ACCENT_GREEN),
            const SizedBox(height: 16),
            Text(
              'Analyzing ${widget.symbol} news...\nThis may take up to 60 seconds',
              textAlign: TextAlign.center,
              style: BODY_SECONDARY,
            ),
          ],
        ),
      );
    }

    if (sentimentError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: COLOR_NEGATIVE, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sentiment analysis failed',
              style: HEADING_SMALL,
            ),
            const SizedBox(height: 8),
            Text(
              sentimentError!,
              style: BODY_SECONDARY,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ACCENT_GREEN,
              ),
              onPressed: _loadSentimentData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (sentimentData == null) {
      return Center(
        child: Text(
          'No sentiment data available',
          style: BODY_PRIMARY,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Overall Sentiment'),
          const SizedBox(height: 16),
          SentimentOverview(sentimentData: sentimentData!),
          const SizedBox(height: 24),
          InfoCard(
            icon: Icons.psychology_outlined,
            iconColor: COLOR_INFO,
            title: 'How Sentiment Analysis Works',
            summary: 'AI-powered market sentiment from news articles',
            detailedInfo: '''
Our sentiment analysis uses advanced Natural Language Processing (NLP) with BERT (Bidirectional Encoder Representations from Transformers), a state-of-the-art AI model.

How it works:
1. News Aggregation: We collect recent news articles about the stock
2. Text Analysis: BERT analyzes the context and tone of each article
3. Sentiment Classification: Each article is rated as Positive, Neutral, or Negative
4. Confidence Score: The AI provides a confidence level for each classification
5. Overall Score: We aggregate individual scores into an overall sentiment

What the results mean:
• Positive Sentiment (>50%): Optimistic news coverage, potential buying interest
• Neutral Sentiment (40-60%): Mixed or factual reporting without clear bias
• Negative Sentiment (<50%): Concerning news coverage, potential selling pressure

Important Notes:
- Sentiment is just one factor - always do comprehensive research
- High confidence scores (>80%) are more reliable
- Recent news has more weight than older articles
- Combine with fundamental and technical analysis for best results
            ''',
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'News Analysis'),
          const SizedBox(height: 16),
          NewsList(news: sentimentData!.newsItems),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ACCENT_GREEN),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewsFeedPage(symbol: widget.symbol),
                  ),
                );
              },
              child: const Text('View all news'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.error, color: COLOR_NEGATIVE, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: HEADING_SMALL,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: BODY_SECONDARY,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ACCENT_GREEN,
            ),
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
    Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        labelColor: TEXT_PRIMARY,
        unselectedLabelColor: TEXT_SECONDARY,
        indicatorColor: ACCENT_GREEN,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Sentiment'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: ACCENT_GREEN),
      );
    }

    if (historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: COLOR_NEGATIVE, size: 48),
            const SizedBox(height: 12),
            Text('Failed to load history', style: HEADING_SMALL),
            const SizedBox(height: 8),
            Text(historyError!, style: BODY_SECONDARY, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ACCENT_GREEN),
              onPressed: _loadSentimentHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (sentimentTrend.isEmpty && dailySummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: TEXT_DISABLED),
            const SizedBox(height: 12),
            Text('No historical data yet', style: HEADING_SMALL),
            const SizedBox(height: 8),
            Text(
              'Sentiment history will appear here after\nthe AI analyzes news over multiple days.',
              style: BODY_SECONDARY,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentiment Trend Chart
          if (sentimentTrend.isNotEmpty) ...[
            const SectionTitle(title: 'Sentiment Trend'),
            const SizedBox(height: 8),
            Text(
              'Average daily sentiment score over time',
              style: CAPTION_TEXT,
            ),
            const SizedBox(height: 12),
            _buildSentimentTrendChart(),
            const SizedBox(height: 24),
          ],

          // Daily Summary Cards
          if (dailySummary.isNotEmpty) ...[
            const SectionTitle(title: 'Daily Breakdown'),
            const SizedBox(height: 12),
            ...dailySummary.map((day) => _buildDailySummaryCard(day)),
          ],
        ],
      ),
    );
  }

  Widget _buildSentimentTrendChart() {
    final spots = sentimentTrend.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.avgScore);
    }).toList();

    final isPositive = spots.isNotEmpty && spots.last.y >= 0;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: BORDER_COLOR,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(color: TEXT_SECONDARY, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (sentimentTrend.length / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sentimentTrend.length) return const SizedBox.shrink();
                  final dateStr = sentimentTrend[idx].date;
                  final short = dateStr.length >= 10 ? dateStr.substring(5, 10) : dateStr;
                  return Text(
                    short,
                    style: const TextStyle(color: TEXT_SECONDARY, fontSize: 9),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3,
                  color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(DailySentimentSummary day) {
    final total = day.positiveCount + day.neutralCount + day.negativeCount;
    final positivePercent = total > 0 ? (day.positiveCount / total * 100) : 0.0;
    final neutralPercent = total > 0 ? (day.neutralCount / total * 100) : 0.0;
    final negativePercent = total > 0 ? (day.negativeCount / total * 100) : 0.0;
    final dateShort = day.date.length >= 10 ? day.date.substring(0, 10) : day.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(dateShort, style: HEADING_SMALL),
              Text(
                '${day.totalAnalyses} articles',
                style: CAPTION_TEXT,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (day.positiveCount > 0)
                  Expanded(
                    flex: day.positiveCount,
                    child: Container(height: 8, color: COLOR_POSITIVE),
                  ),
                if (day.neutralCount > 0)
                  Expanded(
                    flex: day.neutralCount,
                    child: Container(height: 8, color: COLOR_WARNING),
                  ),
                if (day.negativeCount > 0)
                  Expanded(
                    flex: day.negativeCount,
                    child: Container(height: 8, color: COLOR_NEGATIVE),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryChip('Pos', positivePercent, COLOR_POSITIVE),
              _buildSummaryChip('Neu', neutralPercent, COLOR_WARNING),
              _buildSummaryChip('Neg', negativePercent, COLOR_NEGATIVE),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avg Score: ${day.avgSentimentScore.toStringAsFixed(2)}',
                style: BODY_SECONDARY.copyWith(fontSize: 12),
              ),
              Text(
                'Confidence: ${(day.avgConfidence * 100).toStringAsFixed(0)}%',
                style: BODY_SECONDARY.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, double percent, Color color) {
    return Column(
      children: [
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: CAPTION_TEXT),
      ],
    );
  }
}
