import 'package:flutter/material.dart';
import '../backend/models.dart';
import '../backend/providers.dart';
import '../utils/constant.dart';

/// "Doggo Sent of the Market" - Market sentiment overview widget
/// Displays overall bullish/bearish sentiment, top trending symbols, and 24h trend
class DoggoSentimentWidget extends StatefulWidget {
  final DoggoSentimentProvider sentimentProvider;
  final VoidCallback? onRefresh;

  const DoggoSentimentWidget({
    Key? key,
    required this.sentimentProvider,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<DoggoSentimentWidget> createState() => _DoggoSentimentWidgetState();
}

class _DoggoSentimentWidgetState extends State<DoggoSentimentWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Load sentiment data on init
    widget.sentimentProvider.fetchSentiment();
    
    // Listen for updates
    widget.sentimentProvider.addListener(() {
      if (mounted) {
        _animationController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.sentimentProvider.removeListener(() {});
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await widget.sentimentProvider.refresh();
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sentiment = widget.sentimentProvider.sentiment;
    final isLoading = widget.sentimentProvider.isLoading;
    final error = widget.sentimentProvider.error;

    if (isLoading && sentiment == null) {
      return _buildLoadingState();
    }

    if (error != null && sentiment == null) {
      return _buildErrorState(error);
    }

    if (sentiment == null) {
      return SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF66BB6A),
      backgroundColor: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF262626),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF313131),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: sentiment.bullishPercentage > 50
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFFF44336).withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with logo and title
              _buildHeader(sentiment),
              SizedBox(height: 16),
              
              // Overall sentiment gauge
              _buildSentimentGauge(sentiment),
              SizedBox(height: 20),
              
              // Top bullish and bearish stocks
              _buildTopStocks(sentiment),
              SizedBox(height: 20),
              
              // 24h trend chart
              _buildTrendChart(sentiment),
              
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DoggoSentiment sentiment) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E7D32),
            ),
            child: Center(
              child: Text('🐕', style: TextStyle(fontSize: 28)),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doggo Sent of the Market',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Overall: ${sentiment.overallTrend}',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sentiment.bullishPercentage > 50
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : const Color(0xFFF44336).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sentiment.bullishPercentage > 50
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
                width: 1,
              ),
            ),
            child: Text(
              sentiment.bullishPercentage > 50 ? '📈 Bullish' : '📉 Bearish',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sentiment.bullishPercentage > 50
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentGauge(DoggoSentiment sentiment) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Sentiment',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          
          // Sentiment bars
          Row(
            children: [
              _buildSentimentBar(
                'Bullish',
                sentiment.bullishCount,
                sentiment.bullishPercentage,
                const Color(0xFF4CAF50),
              ),
              SizedBox(width: 8),
              _buildSentimentBar(
                'Neutral',
                sentiment.neutralCount,
                sentiment.neutralPercentage,
                const Color(0xFF9E9E9E),
              ),
              SizedBox(width: 8),
              _buildSentimentBar(
                'Bearish',
                sentiment.bearishCount,
                sentiment.bearishPercentage,
                const Color(0xFFF44336),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Sentiment gauge circular progress
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(
              CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
            ),
            child: Center(
              child: CustomPaint(
                size: Size(150, 150),
                painter: SentimentGaugePainter(
                  bullishPercentage: sentiment.bullishPercentage,
                  bearishPercentage: sentiment.bearishPercentage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBar(
    String label,
    int count,
    double percentage,
    Color color,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: const Color(0xFF9E9E9E),
            ),
          ),
          SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 24,
              backgroundColor: const Color(0xFF303030),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}% ($count)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStocks(DoggoSentiment sentiment) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Bullish',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Text(
                'Top Bearish',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF44336),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bullish stocks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sentiment.topBullishSymbols
                      .take(3)
                      .map((stock) => _buildStockBadge(
                        stock.symbol,
                        stock.sentimentScore,
                        const Color(0xFF4CAF50),
                      ))
                      .toList(),
                ),
              ),
              SizedBox(width: 12),
              // Bearish stocks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sentiment.topBearishSymbols
                      .take(3)
                      .map((stock) => _buildStockBadge(
                        stock.symbol,
                        stock.sentimentScore,
                        const Color(0xFFF44336),
                      ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(String symbol, double score, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${score.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(DoggoSentiment sentiment) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '24h Trend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: Size(double.infinity, 100),
              painter: TrendChartPainter(
                trend: sentiment.sentimentTrend24h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: const Color(0xFF313131),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF66BB6A),
          ),
          SizedBox(height: 12),
          Text(
            'Loading market sentiment...',
            style: TextStyle(
              color: const Color(0xFF9E9E9E),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF44336).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFFF44336),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: const Color(0xFFF44336),
            size: 24,
          ),
          SizedBox(height: 12),
          Text(
            'Failed to load market sentiment',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF44336),
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFFE0E0E0),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for sentiment gauge
class SentimentGaugePainter extends CustomPainter {
  final double bullishPercentage;
  final double bearishPercentage;

  SentimentGaugePainter({
    required this.bullishPercentage,
    required this.bearishPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF303030)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Bullish arc (left side)
    final bullishAngle = (bullishPercentage / 100) * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      bullishAngle,
      false,
      Paint()
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Bearish arc (right side)
    final bearishAngle = (bearishPercentage / 100) * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159 / 2,
      bearishAngle,
      false,
      Paint()
        ..color = const Color(0xFFF44336)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${bullishPercentage.toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(SentimentGaugePainter oldDelegate) {
    return oldDelegate.bullishPercentage != bullishPercentage ||
        oldDelegate.bearishPercentage != bearishPercentage;
  }
}

/// Custom painter for trend chart
class TrendChartPainter extends CustomPainter {
  final List<HourlyTrend> trend;

  TrendChartPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    final width = size.width / (trend.length - 1);
    final height = size.height;

    Path path = Path();

    for (int i = 0; i < trend.length; i++) {
      final x = i * width;
      final y = height - (trend[i].bullishPercentage / 100 * height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 2, pointPaint);
    }

    canvas.drawPath(path, paint);

    // Draw baseline
    canvas.drawLine(
      Offset(0, height),
      Offset(size.width, height),
      Paint()
        ..color = const Color(0xFF424242)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(TrendChartPainter oldDelegate) => true;
}
