import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class SocialSentimentPage extends StatefulWidget {
  final String? initialSymbol;

  const SocialSentimentPage({Key? key, this.initialSymbol}) : super(key: key);

  @override
  _SocialSentimentPageState createState() => _SocialSentimentPageState();
}

class _SocialSentimentPageState extends State<SocialSentimentPage> {
  final TextEditingController _symbolController = TextEditingController();
  SocialSentimentResponse? _sentimentData;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSymbol != null) {
      _symbolController.text = widget.initialSymbol!;
      _loadSentiment(widget.initialSymbol!);
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _loadSentiment(String symbol) async {
    if (symbol.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await DogonomicsAPI.fetchSocialSentiment(symbol.toUpperCase(), limit: 15);
      if (mounted) {
        setState(() {
          _sentimentData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: CARD_BACKGROUND,
        title: const Text('Social Sentiment', style: TextStyle(color: TEXT_PRIMARY)),
        iconTheme: const IconThemeData(color: TEXT_PRIMARY),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ACCENT_GREEN_BRIGHT))
                : _error != null
                    ? _buildErrorState()
                    : _sentimentData != null
                        ? _buildSentimentContent()
                        : _buildEmptyPrompt(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: CARD_BACKGROUND,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _symbolController,
              style: const TextStyle(color: TEXT_PRIMARY),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter stock symbol (e.g. AAPL)',
                hintStyle: const TextStyle(color: TEXT_DISABLED),
                filled: true,
                fillColor: CARD_BACKGROUND_ELEVATED,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BORDER_COLOR),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BORDER_COLOR),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ACCENT_GREEN_LIGHT),
                ),
                prefixIcon: const Icon(Icons.search, color: TEXT_SECONDARY),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (value) => _loadSentiment(value),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _loadSentiment(_symbolController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: ACCENT_GREEN,
              foregroundColor: TEXT_PRIMARY,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_outlined, color: TEXT_DISABLED, size: 64),
          const SizedBox(height: 16),
          Text('Enter a stock symbol to analyze sentiment', style: BODY_SECONDARY),
          const SizedBox(height: 8),
          Text('Powered by FinBERT AI', style: CAPTION_TEXT),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: COLOR_NEGATIVE, size: 48),
            const SizedBox(height: 16),
            Text('Analysis Failed', style: HEADING_SMALL),
            const SizedBox(height: 8),
            Text(_error!, style: CAPTION_TEXT, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadSentiment(_symbolController.text),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ACCENT_GREEN, foregroundColor: TEXT_PRIMARY,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentContent() {
    final data = _sentimentData!;
    return RefreshIndicator(
      onRefresh: () => _loadSentiment(_symbolController.text),
      color: ACCENT_GREEN_BRIGHT,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOverallSentimentCard(data),
          const SizedBox(height: 16),
          _buildSentimentGauge(data),
          const SizedBox(height: 16),
          _buildSentimentBreakdown(data),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.article_outlined, color: ACCENT_GREEN_LIGHT, size: 20),
              const SizedBox(width: 8),
              Text('Analyzed Articles (${data.articlesCount})', style: HEADING_SMALL),
            ],
          ),
          const SizedBox(height: 8),
          ...data.articles.map((a) => _buildArticleCard(a)),
        ],
      ),
    );
  }

  Widget _buildOverallSentimentCard(SocialSentimentResponse data) {
    final label = data.overallLabel;
    Color labelColor;
    IconData labelIcon;
    switch (label) {
      case 'positive':
        labelColor = COLOR_POSITIVE;
        labelIcon = Icons.sentiment_satisfied_alt;
        break;
      case 'negative':
        labelColor = COLOR_NEGATIVE;
        labelIcon = Icons.sentiment_dissatisfied;
        break;
      default:
        labelColor = COLOR_WARNING;
        labelIcon = Icons.sentiment_neutral;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: gradientCardDecoration(
        startColor: labelColor.withOpacity(0.15),
        endColor: CARD_BACKGROUND,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: labelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(labelIcon, color: labelColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.symbol.toUpperCase(),
                  style: const TextStyle(color: TEXT_SECONDARY, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${label[0].toUpperCase()}${label.substring(1)} Sentiment',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on ${data.articlesCount} articles',
                  style: CAPTION_TEXT,
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                data.averageScore.toStringAsFixed(3),
                style: TextStyle(color: labelColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text('Score', style: CAPTION_TEXT),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentGauge(SocialSentimentResponse data) {
    // Score ranges from -1 (negative) to 1 (positive)
    final normalizedScore = (data.averageScore + 1) / 2; // 0 to 1

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sentiment Gauge', style: HEADING_SMALL),
          const SizedBox(height: 16),
          // Gauge bar
          Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [COLOR_NEGATIVE, COLOR_WARNING, COLOR_POSITIVE],
              ),
            ),
            child: Stack(
              children: [
                // Indicator
                Positioned(
                  left: (normalizedScore.clamp(0.0, 1.0)) *
                      (MediaQuery.of(context).size.width - 96), // approx width
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: TEXT_PRIMARY,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Bearish', style: TextStyle(color: COLOR_NEGATIVE, fontSize: 11)),
              Text('Neutral', style: TextStyle(color: COLOR_WARNING, fontSize: 11)),
              Text('Bullish', style: TextStyle(color: COLOR_POSITIVE, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Confidence: ${(data.averageConfidence * 100).toStringAsFixed(1)}%',
                  style: CAPTION_TEXT),
              Text('Score: ${data.averageScore.toStringAsFixed(4)}',
                  style: CAPTION_TEXT),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBreakdown(SocialSentimentResponse data) {
    final counts = data.sentimentCounts;
    final total = max(1, counts.values.fold(0, (a, b) => a + b));
    final posPct = ((counts['positive'] ?? 0) / total * 100);
    final neuPct = ((counts['neutral'] ?? 0) / total * 100);
    final negPct = ((counts['negative'] ?? 0) / total * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sentiment Breakdown', style: HEADING_SMALL),
          const SizedBox(height: 16),
          _buildBreakdownBar('Positive', counts['positive'] ?? 0, posPct, COLOR_POSITIVE),
          const SizedBox(height: 10),
          _buildBreakdownBar('Neutral', counts['neutral'] ?? 0, neuPct, COLOR_WARNING),
          const SizedBox(height: 10),
          _buildBreakdownBar('Negative', counts['negative'] ?? 0, negPct, COLOR_NEGATIVE),
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(String label, int count, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$count (${pct.toStringAsFixed(1)}%)', style: CAPTION_TEXT),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: CARD_BACKGROUND_ELEVATED,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard(SocialSentimentArticle article) {
    Color sentColor = TEXT_SECONDARY;
    String sentLabel = 'Unknown';
    if (article.sentiment != null) {
      final s = article.sentiment!;
      sentLabel = '${s.label[0].toUpperCase()}${s.label.substring(1)}';
      switch (s.label) {
        case 'positive':
          sentColor = COLOR_POSITIVE;
          break;
        case 'negative':
          sentColor = COLOR_NEGATIVE;
          break;
        default:
          sentColor = COLOR_WARNING;
      }
    }

    return GestureDetector(
      onTap: () => _openUrl(article.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.imageUrl != null && article.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      article.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: TEXT_PRIMARY,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (article.description.isNotEmpty)
                        Text(
                          article.description,
                          style: const TextStyle(color: TEXT_SECONDARY, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sentLabel,
                    style: TextStyle(color: sentColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (article.sentiment != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Score: ${article.sentiment!.score.toStringAsFixed(3)}',
                    style: CAPTION_TEXT,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Conf: ${(article.sentiment!.confidence * 100).toStringAsFixed(0)}%',
                    style: CAPTION_TEXT,
                  ),
                ],
                const Spacer(),
                Text(
                  article.source,
                  style: const TextStyle(color: ACCENT_GREEN_LIGHT, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
