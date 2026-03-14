import 'package:Dogonomics/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:Dogonomics/backend/dogonomicsApi.dart';

class MarketIndicatorsPage extends StatefulWidget {
  const MarketIndicatorsPage({Key? key}) : super(key: key);

  @override
  _MarketIndicatorsPageState createState() => _MarketIndicatorsPageState();
}

class _MarketIndicatorsPageState extends State<MarketIndicatorsPage> {
  final List<MarketIndex> indices = [
    MarketIndex(
      symbol: 'SPY',
      name: 'S&P 500 ETF',
      description: 'Tracks the S&P 500 index',
      color: Colors.blue,
    ),
    MarketIndex(
      symbol: 'QQQ',
      name: 'NASDAQ-100 ETF',
      description: 'Tracks top 100 NASDAQ stocks',
      color: Colors.green,
    ),
    MarketIndex(
      symbol: 'DIA',
      name: 'Dow Jones ETF',
      description: 'Tracks the Dow Jones Industrial Average',
      color: Colors.orange,
    ),
    MarketIndex(
      symbol: 'IWM',
      name: 'Russell 2000 ETF',
      description: 'Tracks small-cap stocks',
      color: Colors.purple,
    ),
    MarketIndex(
      symbol: 'VIX',
      name: 'Volatility Index',
      description: 'Market fear gauge',
      color: Colors.red,
    ),
  ];

  Map<String, QuoteData?> quotes = {};
  Map<String, bool> loading = {};
  Map<String, String?> errors = {};

  @override
  void initState() {
    super.initState();
    _loadAllQuotes();
  }

  Future<void> _loadAllQuotes() async {
    for (var index in indices) {
      setState(() {
        loading[index.symbol] = true;
        errors[index.symbol] = null;
      });

      try {
        final quote = await DogonomicsAPI.fetchQuote(index.symbol);
        if (mounted) {
          setState(() {
            quotes[index.symbol] = quote;
            loading[index.symbol] = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            errors[index.symbol] = e.toString();
            loading[index.symbol] = false;
          });
        }
      }
    }
  }

  Future<void> _refreshQuotes() async {
    await _loadAllQuotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKG_COLOR,
      appBar: AppBar(
        backgroundColor: MAINGREY,
        title: const Text(
          'Market Indicators',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshQuotes,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshQuotes,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMarketOverview(),
            const SizedBox(height: 24),
            ...indices.map((index) => _buildIndexCard(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverview() {
    final allLoaded = indices.every((index) => quotes[index.symbol] != null);
    
    if (!allLoaded) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: STOCK_CARD,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Loading market data...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    int positiveCount = 0;
    int negativeCount = 0;

    for (var index in indices) {
      final quote = quotes[index.symbol];
      if (quote != null && quote.percentChange != 0) {
        if (quote.percentChange > 0) {
          positiveCount++;
        } else {
          negativeCount++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            STOCK_CARD,
            STOCK_CARD.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: ACCENT_COLOR,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Market Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewStat(
                'Up',
                positiveCount.toString(),
                Colors.green,
                Icons.trending_up,
              ),
              _buildOverviewStat(
                'Down',
                negativeCount.toString(),
                Colors.red,
                Icons.trending_down,
              ),
              _buildOverviewStat(
                'Neutral',
                (indices.length - positiveCount - negativeCount).toString(),
                Colors.grey,
                Icons.trending_flat,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _getMarketSentiment(positiveCount, negativeCount),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _getMarketSentiment(int positive, int negative) {
    if (positive > negative) {
      return '🐂 Market is showing bullish sentiment';
    } else if (negative > positive) {
      return '🐻 Market is showing bearish sentiment';
    } else {
      return '➡️ Market is showing mixed sentiment';
    }
  }

  Widget _buildIndexCard(MarketIndex index) {
    final isLoading = loading[index.symbol] ?? false;
    final error = errors[index.symbol];
    final quote = quotes[index.symbol];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: quote != null ? () => _showDetailsDialog(index, quote) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: index.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.show_chart,
                        color: index.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            index.symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            index.name,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(
                    'Failed to load',
                    style: TextStyle(color: Colors.red[300], fontSize: 12),
                  )
                else if (quote != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${quote.currentPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            index.description,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: quote.percentChange >= 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              quote.percentChange >= 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: quote.percentChange >= 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${quote.percentChange >= 0 ? '+' : ''}${quote.percentChange.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: quote.percentChange >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else
                  const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(MarketIndex index, QuoteData quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: STOCK_CARD,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.show_chart, color: index.color),
            const SizedBox(width: 8),
            Text(
              index.symbol,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Current Price', '\$${quote.currentPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Change', '\$${quote.change.toStringAsFixed(2)}'),
            _buildDetailRow('Change %', '${quote.percentChange.toStringAsFixed(2)}%'),
            _buildDetailRow('Open', '\$${quote.openPrice.toStringAsFixed(2)}'),
            _buildDetailRow('High', '\$${quote.highPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Low', '\$${quote.lowPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Previous Close', '\$${quote.previousClose.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
      ),
    );
  }
}

class MarketIndex {
  final String symbol;
  final String name;
  final String description;
  final Color color;

  MarketIndex({
    required this.symbol,
    required this.name,
    required this.description,
    required this.color,
  });
}