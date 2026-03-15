import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/widgets/explain_tooltip_widget.dart';
import 'package:flutter/material.dart';

class DogonomicsAdvicePage extends StatefulWidget {
  final String symbol;
  const DogonomicsAdvicePage({Key? key, required this.symbol}) : super(key: key);

  @override
  State<DogonomicsAdvicePage> createState() => _DogonomicsAdvicePageState();
}

class _DogonomicsAdvicePageState extends State<DogonomicsAdvicePage> {
  DogonomicsAdviceResponse? _advice;
  FinancialIndicatorsResponse? _indicators;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load advice and indicators independently
    DogonomicsAdviceResponse? advice;
    FinancialIndicatorsResponse? indicators;

    try {
      advice = await DogonomicsAPI.fetchDogonomicsAdvice(widget.symbol);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      return;
    }

    try {
      indicators = await DogonomicsAPI.fetchFinancialIndicators(widget.symbol);
    } catch (_) {
      // Non-fatal
    }

    if (mounted) {
      setState(() {
        _advice = advice;
        _indicators = indicators;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKG_COLOR,
      appBar: AppBar(
        backgroundColor: CARD_BACKGROUND,
        title: Text(
          'Dogonomics Recommendation: ${widget.symbol}',
          style: const TextStyle(color: TEXT_PRIMARY, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: TEXT_PRIMARY),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: TEXT_PRIMARY),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 48, color: ACCENT_GREEN_BRIGHT),
            SizedBox(height: 16),
            CircularProgressIndicator(color: ACCENT_GREEN_BRIGHT),
            SizedBox(height: 16),
            Text(
              'Analyzing recommendation model...',
              style: TextStyle(color: TEXT_SECONDARY, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Processing sentiment, technicals, and fundamentals',
              style: TextStyle(color: TEXT_DISABLED, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: COLOR_NEGATIVE, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load advice', style: HEADING_SMALL),
              const SizedBox(height: 8),
              Text(_error!, style: CAPTION_TEXT, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ACCENT_GREEN,
                  foregroundColor: TEXT_PRIMARY,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_advice == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: ACCENT_GREEN_BRIGHT,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRecommendationCard(),
          const SizedBox(height: 16),
          _buildScoreGauge(),
          const SizedBox(height: 16),
          _buildComponentsSection(),
          if (_indicators != null) ...[
            const SizedBox(height: 16),
            _buildTechnicalIndicatorsSection(),
            const SizedBox(height: 16),
            _buildKeyMetricsSection(),
          ],
          const SizedBox(height: 24),
          _buildDisclaimerCard(),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final advice = _advice!;
    final recColor = _getRecommendationColor(advice.recommendation);
    final recIcon = _getRecommendationIcon(advice.recommendation);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [recColor.withOpacity(0.15), CARD_BACKGROUND],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: recColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(recIcon, color: recColor, size: 48),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              advice.recommendation,
              style: TextStyle(
                color: recColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            ExplainTooltipWidget(
              metricName: 'Recommendation',
              metricValue: advice.recommendation,
              iconSize: 14,
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            widget.symbol,
            style: const TextStyle(color: TEXT_SECONDARY, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '\$${advice.currentPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: TEXT_PRIMARY, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: advice.changePercent >= 0
                      ? COLOR_POSITIVE.withOpacity(0.2)
                      : COLOR_NEGATIVE.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${advice.changePercent >= 0 ? '+' : ''}${advice.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: advice.changePercent >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMetricChip(
                'Confidence',
                '${(advice.confidence * 100).toStringAsFixed(0)}%',
                ACCENT_GREEN_LIGHT,
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                'Data Points',
                advice.dataPoints.toString(),
                CHART_SECONDARY,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: TEXT_SECONDARY, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScoreGauge() {
    final score = _advice!.score;
    // Normalize score from -100..+100 to 0..1
    final normalized = (score + 100) / 200.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: ACCENT_GREEN_LIGHT, size: 20),
              const SizedBox(width: 8),
              Text('Aggregate Score', style: HEADING_SMALL),
              const SizedBox(width: 6),
              ExplainTooltipWidget(
                metricName: 'Aggregate Score',
                metricValue: score.toStringAsFixed(1),
                iconSize: 13,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          COLOR_NEGATIVE,
                          COLOR_WARNING,
                          COLOR_POSITIVE,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (normalized * (MediaQuery.of(context).size.width - 72)).clamp(0.0, double.infinity),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Strong Sell', style: TextStyle(color: COLOR_NEGATIVE, fontSize: 11)),
              Text(
                'Score: ${score.toStringAsFixed(1)}',
                style: const TextStyle(color: TEXT_PRIMARY, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Text('Strong Buy', style: TextStyle(color: COLOR_POSITIVE, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 18, color: ACCENT_GREEN_LIGHT),
              const SizedBox(width: 8),
              Text('Key Analysis Signals', style: HEADING_SMALL),
            ],
          ),
          const SizedBox(height: 16),
          ..._advice!.components.map((comp) => _buildComponentRow(comp)),
        ],
      ),
    );
  }

  Widget _buildComponentRow(AdviceComponent comp) {
    final signalColor = _getSignalColor(comp.signal);
    final barWidth = ((comp.score.abs() / 100.0) * 120).clamp(4.0, 120.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  comp.name,
                  style: const TextStyle(color: TEXT_PRIMARY, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  comp.signal,
                  style: TextStyle(color: signalColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: barWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: comp.score >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${comp.score >= 0 ? '+' : ''}${comp.score.toStringAsFixed(1)}',
                style: TextStyle(
                  color: comp.score >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${(comp.weight * 100).toStringAsFixed(0)}% weight)',
                style: const TextStyle(color: TEXT_DISABLED, fontSize: 11),
              ),
            ],
          ),
          if (comp.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comp.details,
              style: const TextStyle(color: TEXT_SECONDARY, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechnicalIndicatorsSection() {
    final indicators = _indicators!.technicalIndicators;
    if (indicators.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: CHART_PRIMARY, size: 20),
              const SizedBox(width: 8),
              Text('Technical Indicators', style: HEADING_SMALL),
            ],
          ),
          const SizedBox(height: 12),
          ...indicators.map((ind) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatIndicatorName(ind.name),
                    style: const TextStyle(color: TEXT_SECONDARY, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    ind.value.toStringAsFixed(2),
                    style: const TextStyle(color: TEXT_PRIMARY, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getSignalColor(ind.signal).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ind.signal,
                    style: TextStyle(
                      color: _getSignalColor(ind.signal),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsSection() {
    final metrics = _indicators!.keyMetrics;
    if (metrics.isEmpty) return const SizedBox();

    // Select most important metrics to display
    final displayMetrics = <MapEntry<String, String>>[];

    void addMetric(String key, String label, {String suffix = '', int decimals = 2}) {
      if (metrics.containsKey(key) && metrics[key] != null) {
        final val = metrics[key];
        if (val is num) {
          displayMetrics.add(MapEntry(label, '${val.toDouble().toStringAsFixed(decimals)}$suffix'));
        }
      }
    }

    addMetric('peBasicExclExtraTTM', 'P/E Ratio');
    addMetric('epsBasicExclExtraTTM', 'EPS', suffix: '');
    addMetric('psTTM', 'P/S Ratio');
    addMetric('pbQuarterly', 'P/B Ratio');
    addMetric('roeTTM', 'ROE', suffix: '%');
    addMetric('roaTTM', 'ROA', suffix: '%');
    addMetric('grossMarginTTM', 'Gross Margin', suffix: '%');
    addMetric('netProfitMarginTTM', 'Net Margin', suffix: '%');
    addMetric('operatingMarginTTM', 'Operating Margin', suffix: '%');
    addMetric('currentRatioQuarterly', 'Current Ratio');
    addMetric('debtEquityQuarterly', 'Debt/Equity');
    addMetric('dividendYieldIndicatedAnnual', 'Dividend Yield', suffix: '%');
    addMetric('beta', 'Beta');
    addMetric('52WeekHigh', '52W High');
    addMetric('52WeekLow', '52W Low');
    addMetric('revenueGrowthTTM5Y', '5Y Rev Growth', suffix: '%');

    if (displayMetrics.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: CHART_SECONDARY, size: 20),
              const SizedBox(width: 8),
              Text('Key Financial Metrics', style: HEADING_SMALL),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayMetrics.map((entry) => Container(
              width: (MediaQuery.of(context).size.width - 56) / 2,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CARD_BACKGROUND_ELEVATED,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(color: TEXT_SECONDARY, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(color: TEXT_PRIMARY, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: COLOR_WARNING.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: COLOR_WARNING.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: COLOR_WARNING),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This recommendation is generated from automated analysis of news sentiment, technical indicators, and financial metrics. '
              'This is not financial advice — always do your own research before making investment decisions.',
              style: TextStyle(color: COLOR_WARNING.withOpacity(0.8), fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Color _getRecommendationColor(String rec) {
    switch (rec) {
      case 'STRONG BUY':
        return const Color(0xFF00E676);
      case 'BUY':
        return COLOR_POSITIVE;
      case 'SELL':
        return COLOR_NEGATIVE;
      case 'STRONG SELL':
        return const Color(0xFFFF1744);
      default:
        return COLOR_WARNING;
    }
  }

  IconData _getRecommendationIcon(String rec) {
    switch (rec) {
      case 'STRONG BUY':
      case 'BUY':
        return Icons.thumb_up_alt;
      case 'SELL':
      case 'STRONG SELL':
        return Icons.thumb_down_alt;
      default:
        return Icons.thumbs_up_down;
    }
  }

  Color _getSignalColor(String signal) {
    switch (signal) {
      case 'BUY':
        return COLOR_POSITIVE;
      case 'SELL':
        return COLOR_NEGATIVE;
      default:
        return COLOR_WARNING;
    }
  }

  String _formatIndicatorName(String name) {
    return name.replaceAll('_', ' ');
  }
}
