import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PortfolioAnalysisPage extends StatefulWidget {
  final List<Stock> portfolio;
  final double totalValue;
  final double totalDayChange;

  const PortfolioAnalysisPage({
    Key? key,
    required this.portfolio,
    required this.totalValue,
    required this.totalDayChange,
  }) : super(key: key);

  @override
  _PortfolioAnalysisPageState createState() => _PortfolioAnalysisPageState();
}

class _PortfolioAnalysisPageState extends State<PortfolioAnalysisPage> {
  int _selectedTimeframe = 0; // 0 = Today, 1 = Week, 2 = Month, 3 = Year
  bool _isLoadingHistory = false;
  List<FlSpot> _portfolioHistory = [];
  double _timeframeChange = 0.0;
  double _timeframeChangePercent = 0.0;

  static const List<int> _timeframeDays = [1, 7, 30, 365];

  @override
  void initState() {
    super.initState();
    _loadPortfolioHistory();
  }

  Future<void> _loadPortfolioHistory() async {
    if (widget.portfolio.isEmpty) return;

    setState(() => _isLoadingHistory = true);

    try {
      final days = _timeframeDays[_selectedTimeframe];
      // Fetch chart data for top holdings (up to 5)
      final topStocks = List<Stock>.from(widget.portfolio)
        ..sort((a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity));
      final symbols = topStocks.take(5).toList();

      // Fetch historical data for each symbol in parallel
      final futures = symbols.map((s) => DogonomicsAPI.fetchChartData(s.symbol, days: days).catchError((_) => <HistoricalDataPoint>[]));
      final results = await Future.wait(futures);

      // Combine into portfolio value series
      // Find the minimum length across all series
      final lengths = results.where((r) => r.isNotEmpty).map((r) => r.length).toList();
      if (lengths.isEmpty) {
        if (mounted) setState(() => _isLoadingHistory = false);
        return;
      }
      final minLen = lengths.reduce((a, b) => a < b ? a : b);

      final spots = <FlSpot>[];
      double firstVal = 0;
      double lastVal = 0;

      for (int i = 0; i < minLen; i++) {
        double dayValue = 0;
        for (int j = 0; j < results.length; j++) {
          if (results[j].isNotEmpty && i < results[j].length) {
            dayValue += results[j][i].close * symbols[j].quantity;
          }
        }
        spots.add(FlSpot(i.toDouble(), dayValue));
        if (i == 0) firstVal = dayValue;
        if (i == minLen - 1) lastVal = dayValue;
      }

      if (mounted) {
        setState(() {
          _portfolioHistory = spots;
          _timeframeChange = lastVal - firstVal;
          _timeframeChangePercent = firstVal > 0 ? (_timeframeChange / firstVal) * 100 : 0;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: CARD_BACKGROUND,
        title: Text('Portfolio Analysis', style: HEADING_MEDIUM),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TEXT_PRIMARY),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 24),
            _buildTimeframeSelector(),
            const SizedBox(height: 24),
            _buildPortfolioValueChart(),
            const SizedBox(height: 24),
            _buildPerformanceMetrics(),
            const SizedBox(height: 24),
            _buildAllocationChart(),
            const SizedBox(height: 24),
            _buildTopPerformers(),
            const SizedBox(height: 24),
            _buildDiversificationMetrics(),
            const SizedBox(height: 24),
            _buildRiskMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    bool isPositive = widget.totalDayChange >= 0;
    double changePercentage = widget.totalValue > 0 
        ? (widget.totalDayChange / widget.totalValue) * 100 
        : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: gradientCardDecoration(
        startColor: ACCENT_GREEN,
        endColor: ACCENT_GREEN_LIGHT,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Portfolio Value',
                style: HEADING_SMALL.copyWith(color: Colors.white.withOpacity(0.9)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.portfolio.length} Holdings',
                  style: CAPTION_TEXT.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${widget.totalValue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: Colors.white.withOpacity(0.9),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${isPositive ? '+' : ''}\$${widget.totalDayChange.toStringAsFixed(2)} (${changePercentage.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Today\'s Change',
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final timeframes = ['Today', 'Week', 'Month', 'Year'];

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timeframes.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTimeframe == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                timeframes[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : TEXT_SECONDARY,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: ACCENT_GREEN,
              backgroundColor: CARD_BACKGROUND,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedTimeframe = index;
                  });
                  _loadPortfolioHistory();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortfolioValueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: ACCENT_COLOR, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Portfolio Value',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!_isLoadingHistory && _portfolioHistory.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_timeframeChange >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_timeframeChange >= 0 ? '+' : ''}\$${_timeframeChange.toStringAsFixed(2)} (${_timeframeChangePercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: _timeframeChange >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: ACCENT_GREEN))
                : _portfolioHistory.isEmpty
                    ? Center(
                        child: Text(
                          'No historical data available',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[800]!,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _portfolioHistory,
                              isCurved: true,
                              color: _timeframeChange >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: (_timeframeChange >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE)
                                    .withOpacity(0.15),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => CARD_BACKGROUND_ELEVATED,
                              getTooltipItems: (spots) => spots.map((s) {
                                return LineTooltipItem(
                                  '\$${s.y.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: ACCENT_COLOR, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Performance Metrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricRow('Average Stock Value', '\$${_calculateAverageStockValue().toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _buildMetricRow('Total Positions', '${widget.portfolio.length}'),
          const SizedBox(height: 12),
          _buildMetricRow('Winning Positions', '${_getWinningPositions()}'),
          const SizedBox(height: 12),
          _buildMetricRow('Losing Positions', '${_getLosingPositions()}'),
          const SizedBox(height: 12),
          _buildMetricRow('Win Rate', '${_calculateWinRate().toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildAllocationChart() {
    if (widget.portfolio.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: ACCENT_COLOR, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Portfolio Allocation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: _getPieChartSections(),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._buildAllocationLegend(),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return widget.portfolio.asMap().entries.map((entry) {
      final index = entry.key;
      final stock = entry.value;
      final percentage = (stock.price * stock.quantity / widget.totalValue) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: stock.price * stock.quantity,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildAllocationLegend() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return widget.portfolio.asMap().entries.map((entry) {
      final index = entry.key;
      final stock = entry.value;
      final value = stock.price * stock.quantity;
      final percentage = (value / widget.totalValue) * 100;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stock.symbol,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Text(
              '\$${value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTopPerformers() {
    final sortedStocks = List<Stock>.from(widget.portfolio)
      ..sort((a, b) => b.change.compareTo(a.change));
    final topPerformers = sortedStocks.take(3).toList();
    final worstPerformers = sortedStocks.reversed.take(3).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: STOCK_CARD,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Top Performers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...topPerformers.map((stock) => _buildPerformerRow(stock, true)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: STOCK_CARD,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_down, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Worst Performers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...worstPerformers.map((stock) => _buildPerformerRow(stock, false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformerRow(Stock stock, bool isTop) {
    final changePercent = stock.price != 0 ? (stock.change / stock.price) * 100 : 0.0;
    final isPositive = stock.change >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${stock.quantity} shares',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${stock.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiversificationMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: ACCENT_COLOR, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Diversification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricRow('Portfolio Concentration', '${_calculateConcentration().toStringAsFixed(1)}%'),
          const SizedBox(height: 12),
          _buildMetricRow('Largest Position', _getLargestPosition()),
          const SizedBox(height: 12),
          _buildMetricRow('Smallest Position', _getSmallestPosition()),
          const SizedBox(height: 16),
          _buildDiversificationScore(),
        ],
      ),
    );
  }

  Widget _buildDiversificationScore() {
    final score = _calculateDiversificationScore();
    final color = score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Diversification Score',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              '${score.toStringAsFixed(0)}/100',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: ACCENT_COLOR, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Risk Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricRow('Portfolio Volatility', _getVolatilityLevel()),
          const SizedBox(height: 12),
          _buildMetricRow('Risk Level', _getRiskLevel()),
          const SizedBox(height: 12),
          _buildMetricRow('Max Drawdown', '${_calculateMaxDrawdown().toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Calculation Methods
  double _calculateAverageStockValue() {
    if (widget.portfolio.isEmpty) return 0.0;
    return widget.totalValue / widget.portfolio.length;
  }

  int _getWinningPositions() {
    return widget.portfolio.where((stock) => stock.change > 0).length;
  }

  int _getLosingPositions() {
    return widget.portfolio.where((stock) => stock.change < 0).length;
  }

  double _calculateWinRate() {
    if (widget.portfolio.isEmpty) return 0.0;
    return (_getWinningPositions() / widget.portfolio.length) * 100;
  }

  double _calculateConcentration() {
    if (widget.portfolio.isEmpty) return 0.0;
    final largestValue = widget.portfolio.map((s) => s.price * s.quantity).reduce((a, b) => a > b ? a : b);
    return (largestValue / widget.totalValue) * 100;
  }

  String _getLargestPosition() {
    if (widget.portfolio.isEmpty) return 'N/A';
    final largest = widget.portfolio.reduce(
      (a, b) => (a.price * a.quantity) > (b.price * b.quantity) ? a : b
    );
    return '${largest.symbol} (\$${(largest.price * largest.quantity).toStringAsFixed(2)})';
  }

  String _getSmallestPosition() {
    if (widget.portfolio.isEmpty) return 'N/A';
    final smallest = widget.portfolio.reduce(
      (a, b) => (a.price * a.quantity) < (b.price * b.quantity) ? a : b
    );
    return '${smallest.symbol} (\$${(smallest.price * smallest.quantity).toStringAsFixed(2)})';
  }

  double _calculateDiversificationScore() {
    if (widget.portfolio.isEmpty) return 0.0;
    
    // Simple scoring based on number of holdings and concentration
    final numHoldings = widget.portfolio.length;
    final concentration = _calculateConcentration();
    
    double score = 0;
    
    // Points for number of holdings (max 50 points)
    if (numHoldings >= 10) score += 50;
    else score += numHoldings * 5;
    
    // Points for low concentration (max 50 points)
    if (concentration < 20) score += 50;
    else if (concentration < 40) score += 30;
    else if (concentration < 60) score += 10;
    
    return score.clamp(0, 100);
  }

  String _getVolatilityLevel() {
    final avgChange = widget.portfolio.fold(0.0, (sum, stock) {
      final changePercent = stock.price != 0 ? (stock.change / stock.price).abs() * 100 : 0.0;
      return sum + changePercent;
    }) / widget.portfolio.length;
    
    if (avgChange < 2) return 'Low';
    if (avgChange < 5) return 'Medium';
    return 'High';
  }

  String _getRiskLevel() {
    final score = _calculateDiversificationScore();
    if (score >= 70) return 'Low Risk';
    if (score >= 40) return 'Medium Risk';
    return 'High Risk';
  }

  double _calculateMaxDrawdown() {
    // Simplified max drawdown based on worst performer
    if (widget.portfolio.isEmpty) return 0.0;
    final worstChange = widget.portfolio.map((s) {
      return s.price != 0 ? (s.change / s.price) * 100 : 0.0;
    }).reduce((a, b) => a < b ? a : b);
    return worstChange.abs();
  }
}
