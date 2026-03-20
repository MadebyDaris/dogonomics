import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/widgets/doggo_inline_insight.dart';
import 'package:flutter/material.dart';

class EconomicIndicatorsPage extends StatefulWidget {
  const EconomicIndicatorsPage({Key? key}) : super(key: key);

  @override
  _EconomicIndicatorsPageState createState() => _EconomicIndicatorsPageState();
}

class _EconomicIndicatorsPageState extends State<EconomicIndicatorsPage> {
  bool isLoading = false;
  EconomicIndicatorResponse? indicatorData;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEconomicIndicators();
  }

  Future<void> _loadEconomicIndicators() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await DogonomicsAPI.fetchEconomicIndicators();
      if (mounted) {
        setState(() {
          indicatorData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKG_COLOR,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: DoggoInlineInsightWidget(
              context: 'Economic Indicators',
              prompt: 'Give a brief 2-sentence update on major economic indicators like GDP, inflation, and unemployment.',
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: ACCENT_GREEN),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading indicators',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error ?? 'Unknown error',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadEconomicIndicators,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (indicatorData == null || indicatorData!.indicators.isEmpty) {
      return const Center(
        child: Text(
          'No indicators available',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEconomicIndicators,
      color: ACCENT_GREEN,
      backgroundColor: STOCK_CARD,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Source: ${indicatorData!.source}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          ...indicatorData!.indicators.map((indicator) {
            return _buildIndicatorCard(indicator);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(IndicatorData indicator) {
    final latestValue = indicator.latestValue;
    final latestDate = indicator.latestDate;
    
    final formattedValue = latestValue != null 
        ? latestValue.toStringAsFixed(2)
        : 'N/A';
    
    final formattedDate = latestDate != null
        ? '${latestDate.year}-${latestDate.month.toString().padLeft(2, '0')}-${latestDate.day.toString().padLeft(2, '0')}'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            indicator.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Value',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedValue,
                    style: const TextStyle(
                      color: ACCENT_GREEN,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (indicator.history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: const Color(0xFF3A3A3A),
            ),
            const SizedBox(height: 12),
            Text(
              'History (${indicator.history.length} data points)',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: _buildHistoryPreview(indicator.history),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryPreview(List<Observation> history) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'No history data',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    // Show last 10 data points
    final displayHistory = history.length > 10 
        ? history.sublist(history.length - 10)
        : history;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: displayHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final observation = entry.value;
          final value = observation.value ?? 0.0;
          
          // Find min and max for scaling
          final values = displayHistory
              .map((o) => o.value ?? 0.0)
              .toList();
          final minValue = values.reduce((a, b) => a < b ? a : b);
          final maxValue = values.reduce((a, b) => a > b ? a : b);
          final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;
          
          // Normalize to 0-1 range
          final normalized = (value - minValue) / range;
          
          // Scale to 0-40 pixels (out of 60)
          final height = 20 + (normalized * 35);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Tooltip(
              message: '${observation.date.year}-${observation.date.month}-${observation.date.day}: $value',
              child: Container(
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: ACCENT_GREEN,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
