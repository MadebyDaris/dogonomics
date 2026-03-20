import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constant.dart';
import '../utils/tickerData.dart';
import '../backend/dogonomicsApi.dart';

class MarketOverviewWidget extends StatefulWidget {
  const MarketOverviewWidget({super.key});

  @override
  State<MarketOverviewWidget> createState() => _MarketOverviewWidgetState();
}

class _MarketOverviewWidgetState extends State<MarketOverviewWidget> {
  // Major Indices (ETF proxies)
  final List<String> indices = ['SPY', 'QQQ', 'DIA', 'IWM'];
  Map<String, LiveQuote?> quotes = {};
  Map<String, List<HistoricalDataPoint>> historicalData = {};
  bool isLoading = true;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    Map<String, LiveQuote?> fetchedQuotes = {};
    Map<String, List<HistoricalDataPoint>> fetchedHistorical = {};

    final futures = indices.map((symbol) async {
      try {
        final results = await Future.wait<dynamic>([
          fetchLiveQuote(symbol),
          DogonomicsAPI.fetchChartData(symbol, days: 7),
        ]);
        fetchedQuotes[symbol] = results[0] as LiveQuote?;
        fetchedHistorical[symbol] = results[1] as List<HistoricalDataPoint>;
      } catch (e) {
        debugPrint('Error fetching data for $symbol: $e');
      }
    });

    await Future.wait(futures);

    if (mounted) {
      setState(() {
        quotes = fetchedQuotes;
        historicalData = fetchedHistorical;
        isLoading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Market Overview',
                style: HEADING_MEDIUM,
              ),
              const Spacer(),
              if (_lastUpdated != null)
                Text(
                  'Updated ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: TEXT_DISABLED,
                    fontSize: 11,
                  ),
                ),
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, color: TEXT_SECONDARY, size: 18),
                tooltip: 'Refresh market overview',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: indices.length,
            itemBuilder: (context, index) {
              final symbol = indices[index];
              final quote = quotes[symbol];
              final hist = historicalData[symbol];
              return _buildIndexCard(symbol, quote, hist);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIndexCard(String symbol, LiveQuote? quote, List<HistoricalDataPoint>? hist) {
    if (quote == null) {
      return Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final double change = quote.current - quote.previousClose;
    final double percentChange = (change / quote.previousClose) * 100;
    final bool isPositive = change >= 0;
    final Color color = isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE;

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: cardDecoration(
        color: CARD_BACKGROUND,
        borderColor: color.withOpacity(0.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getIndexName(symbol),
                  style: const TextStyle(
                    color: TEXT_SECONDARY,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 16,
                ),
              ],
            ),
            const Spacer(),
            Text(
              quote.current.toStringAsFixed(2),
              style: const TextStyle(
                color: TEXT_PRIMARY,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${percentChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Mini Chart Placeholder (Simulated)
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateMiniChartData(isPositive, hist),
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIndexName(String symbol) {
    switch (symbol) {
      case 'SPY': return 'S&P 500';
      case 'QQQ': return 'Nasdaq 100';
      case 'DIA': return 'Dow Jones';
      case 'IWM': return 'Russell 2000';
      default: return symbol;
    }
  }

  List<FlSpot> _generateMiniChartData(bool isPositive, List<HistoricalDataPoint>? hist) {
    if (hist != null && hist.isNotEmpty) {
      // Sort chronologically just in case
      final sortedHist = List<HistoricalDataPoint>.from(hist)
        ..sort((a, b) => a.date.compareTo(b.date));
      
      List<FlSpot> spots = [];
      // Normalize baseline
      double minPrice = sortedHist.map((p) => p.close).reduce((a, b) => a < b ? a : b);
      // Create spots mapped to index
      for (int i = 0; i < sortedHist.length; i++) {
        spots.add(FlSpot(i.toDouble(), sortedHist[i].close - minPrice));
      }
      return spots;
    }

    // Generate a simple fake trend line based on direction if historic data is not available
    if (isPositive) {
      return const [
        FlSpot(0.0, 1.0), FlSpot(1.0, 1.5), FlSpot(2.0, 1.4), FlSpot(3.0, 2.0), 
        FlSpot(4.0, 2.2), FlSpot(5.0, 1.8), FlSpot(6.0, 2.8)
      ];
    } else {
      return const [
        FlSpot(0.0, 3.0), FlSpot(1.0, 2.5), FlSpot(2.0, 2.6), FlSpot(3.0, 2.0), 
        FlSpot(4.0, 1.8), FlSpot(5.0, 1.5), FlSpot(6.0, 1.0)
      ];
    }
  }
}
