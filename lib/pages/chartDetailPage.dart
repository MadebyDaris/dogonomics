import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../backend/dogonomicsApi.dart';
import '../utils/constant.dart';
import '../widgets/infoTooltip.dart';

class ChartDetailPage extends StatefulWidget {
  final String symbol;
  final String companyName;
  final List<ChartDataPoint> chartData;

  const ChartDetailPage({
    Key? key,
    required this.symbol,
    required this.companyName,
    required this.chartData,
  }) : super(key: key);

  @override
  State<ChartDetailPage> createState() => _ChartDetailPageState();
}

class _ChartDetailPageState extends State<ChartDetailPage> {
  String selectedTimeframe = '1M'; // Default timeframe
  ChartStatistics? statistics;
  late List<ChartDataPoint> _chartData;
  bool _isLoadingChart = false;
  String? _chartError;
  
  final List<String> timeframes = ['1D', '1W', '1M', '3M', '6M', '1Y', 'ALL'];

  static const Map<String, int> _timeframeDays = {
    '1D': 1,
    '1W': 7,
    '1M': 30,
    '3M': 90,
    '6M': 180,
    '1Y': 365,
    'ALL': 1825,
  };

  @override
  void initState() {
    super.initState();
    _chartData = List.from(widget.chartData);
    _calculateStatistics();
  }

  Future<void> _loadChartData(String timeframe) async {
    final days = _timeframeDays[timeframe] ?? 30;
    setState(() {
      _isLoadingChart = true;
      _chartError = null;
    });

    try {
      final historical = await DogonomicsAPI.fetchChartData(widget.symbol, days: days);
      if (mounted) {
        setState(() {
          _chartData = historical
              .asMap()
              .entries
              .map((e) => ChartDataPoint(x: e.key.toDouble(), y: e.value.close))
              .toList();
          _isLoadingChart = false;
        });
        _calculateStatistics();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chartError = e.toString();
          _isLoadingChart = false;
        });
      }
    }
  }

  void _calculateStatistics() {
    if (_chartData.isEmpty) return;

    final prices = _chartData.map((point) => point.y).toList();
    final sortedPrices = List<double>.from(prices)..sort();

    // Find period high/low
    final periodHigh = sortedPrices.last;
    final periodLow = sortedPrices.first;

    // All-time high/low from the initial full dataset
    final allPrices = widget.chartData.map((p) => p.y).toList()..sort();
    final allTimeHigh = allPrices.isNotEmpty ? allPrices.last : periodHigh;
    final allTimeLow = allPrices.isNotEmpty ? allPrices.first : periodLow;

    // Calculate average
    final average = prices.reduce((a, b) => a + b) / prices.length;

    // Calculate volatility (standard deviation)
    final variance = prices.map((price) => (price - average) * (price - average)).reduce((a, b) => a + b) / prices.length;
    final volatility = (variance > 0) ? (variance).abs().toDouble() : 0.0;

    // Calculate change
    final periodChange = ((prices.last - prices.first) / prices.first) * 100;

    // Calculate derivative (rate of change)
    double derivative = 0.0;
    if (_chartData.length > 1) {
      final recentPoints = _chartData.sublist(
        _chartData.length > 5 ? _chartData.length - 5 : 0
      );
      final oldPrice = recentPoints.first.y;
      final newPrice = recentPoints.last.y;
      derivative = newPrice - oldPrice;
    }

    setState(() {
      statistics = ChartStatistics(
        allTimeHigh: allTimeHigh,
        allTimeLow: allTimeLow,
        periodHigh: periodHigh,
        periodLow: periodLow,
        average: average,
        volatility: volatility,
        periodChange: periodChange,
        derivative: derivative,
        dataPoints: _chartData.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: CARD_BACKGROUND,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TEXT_PRIMARY),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.symbol,
              style: HEADING_MEDIUM,
            ),
            Text(
              widget.companyName,
              style: CAPTION_TEXT,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: TEXT_PRIMARY),
            onPressed: () => _showChartInfo(),
          ),
        ],
      ),
      body: _chartData.isEmpty && !_isLoadingChart
          ? _buildEmptyState()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeframeSelector(),
                  _buildExpandedChart(),
                  _buildStatisticsCards(),
                  _buildDetailedMetrics(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_outlined,
            size: 80,
            color: TEXT_DISABLED,
          ),
          const SizedBox(height: 16),
          Text(
            'No chart data available',
            style: HEADING_MEDIUM.copyWith(color: TEXT_SECONDARY),
          ),
          const SizedBox(height: 8),
          Text(
            'Chart data for ${widget.symbol} is currently unavailable',
            style: BODY_SECONDARY,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: timeframes.map((timeframe) {
            final isSelected = selectedTimeframe == timeframe;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(timeframe),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected && timeframe != selectedTimeframe) {
                    setState(() {
                      selectedTimeframe = timeframe;
                    });
                    _loadChartData(timeframe);
                  }
                },
                backgroundColor: CARD_BACKGROUND_ELEVATED,
                selectedColor: ACCENT_GREEN,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : TEXT_SECONDARY,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExpandedChart() {
    if (_isLoadingChart) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        height: 400,
        decoration: cardDecoration(),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: ACCENT_GREEN),
              SizedBox(height: 16),
              Text('Loading chart data...', style: TextStyle(color: TEXT_SECONDARY)),
            ],
          ),
        ),
      );
    }

    if (_chartError != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        height: 400,
        decoration: cardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: COLOR_NEGATIVE, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load chart', style: HEADING_SMALL.copyWith(color: COLOR_NEGATIVE)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _loadChartData(selectedTimeframe),
                child: const Text('Retry', style: TextStyle(color: ACCENT_GREEN)),
              ),
            ],
          ),
        ),
      );
    }

    if (_chartData.isEmpty) return const SizedBox.shrink();

    final prices = _chartData.map((point) => point.y).toList();
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final isPositive = _chartData.last.y >= _chartData.first.y;

    final spots = _chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.y);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Chart',
                    style: HEADING_MEDIUM,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Timeframe: $selectedTimeframe',
                    style: CAPTION_TEXT,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      statistics != null
                          ? '${statistics!.periodChange >= 0 ? '+' : ''}${statistics!.periodChange.toStringAsFixed(2)}%'
                          : 'N/A',
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
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: CHART_GRID,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: CAPTION_TEXT,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= _chartData.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toInt()}',
                          style: CAPTION_TEXT,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: BORDER_COLOR),
                ),
                minY: minPrice * 0.98,
                maxY: maxPrice * 1.02,
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
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => CARD_BACKGROUND_ELEVATED,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '\$${spot.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    if (statistics == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Statistics',
            style: HEADING_MEDIUM,
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildStatCard(
                'All-Time High',
                '\$${statistics!.allTimeHigh.toStringAsFixed(2)}',
                Icons.trending_up,
                COLOR_POSITIVE,
              ),
              _buildStatCard(
                'All-Time Low',
                '\$${statistics!.allTimeLow.toStringAsFixed(2)}',
                Icons.trending_down,
                COLOR_NEGATIVE,
              ),
              _buildStatCard(
                'Period High',
                '\$${statistics!.periodHigh.toStringAsFixed(2)}',
                Icons.arrow_upward,
                COLOR_INFO,
              ),
              _buildStatCard(
                'Period Low',
                '\$${statistics!.periodLow.toStringAsFixed(2)}',
                Icons.arrow_downward,
                COLOR_WARNING,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: CAPTION_TEXT,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: HEADING_SMALL.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics() {
    if (statistics == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detailed Metrics',
                  style: HEADING_MEDIUM,
                ),
                InfoTooltip(
                  title: 'Chart Metrics',
                  message: 'These metrics provide detailed analysis of the chart data including price ranges, trends, and volatility measures.',
                ),
              ],
            ),
          ),
          _buildMetricRow('Average Price', '\$${statistics!.average.toStringAsFixed(2)}'),
          const Divider(color: DIVIDER_COLOR, height: 1),
          _buildMetricRow('Price Range', '\$${(statistics!.periodHigh - statistics!.periodLow).toStringAsFixed(2)}'),
          const Divider(color: DIVIDER_COLOR, height: 1),
          _buildMetricRow('Volatility', statistics!.volatility.toStringAsFixed(4)),
          const Divider(color: DIVIDER_COLOR, height: 1),
          _buildMetricRow(
            'Derivative (Rate of Change)',
            '${statistics!.derivative >= 0 ? '+' : ''}${statistics!.derivative.toStringAsFixed(2)}',
            color: statistics!.derivative >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
          ),
          const Divider(color: DIVIDER_COLOR, height: 1),
          _buildMetricRow('Data Points', statistics!.dataPoints.toString()),
          const Divider(color: DIVIDER_COLOR, height: 1),
          _buildMetricRow(
            'Period Change',
            '${statistics!.periodChange >= 0 ? '+' : ''}${statistics!.periodChange.toStringAsFixed(2)}%',
            color: statistics!.periodChange >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: BODY_SECONDARY,
          ),
          Text(
            value,
            style: BODY_PRIMARY.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showChartInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CARD_BACKGROUND,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: COLOR_INFO),
            const SizedBox(width: 8),
            const Text('Chart Information', style: HEADING_MEDIUM),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Understanding Chart Metrics',
                style: HEADING_SMALL,
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                'All-Time High/Low',
                'The highest and lowest prices ever recorded for this stock.',
              ),
              _buildInfoItem(
                'Period High/Low',
                'The highest and lowest prices within the selected timeframe.',
              ),
              _buildInfoItem(
                'Average Price',
                'The mean price across all data points in the period.',
              ),
              _buildInfoItem(
                'Volatility',
                'Measures price fluctuation. Higher values indicate more price variation.',
              ),
              _buildInfoItem(
                'Derivative',
                'The rate of price change. Positive means upward trend, negative means downward.',
              ),
              _buildInfoItem(
                'Period Change',
                'The percentage change from the start to the end of the period.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: ACCENT_GREEN)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: BODY_SECONDARY,
          ),
        ],
      ),
    );
  }
}

// Statistics Data Model
class ChartStatistics {
  final double allTimeHigh;
  final double allTimeLow;
  final double periodHigh;
  final double periodLow;
  final double average;
  final double volatility;
  final double periodChange;
  final double derivative;
  final int dataPoints;

  ChartStatistics({
    required this.allTimeHigh,
    required this.allTimeLow,
    required this.periodHigh,
    required this.periodLow,
    required this.average,
    required this.volatility,
    required this.periodChange,
    required this.derivative,
    required this.dataPoints,
  });
}
