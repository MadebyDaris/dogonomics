import 'package:flutter/material.dart';
import '../backend/gemini_service.dart';
import '../backend/models.dart';
import '../utils/constant.dart';

/// News summary card displaying article with LLM-generated 3-bullet summary
/// Shows FinBERT sentiment gauge and "Read Full Article" button
class NewsSummaryCardWidget extends StatefulWidget {
  final NewsWithSummary news;
  final VoidCallback onReadMore;
  final Function(List<String>)? onSummaryGenerated;

  const NewsSummaryCardWidget({
    Key? key,
    required this.news,
    required this.onReadMore,
    this.onSummaryGenerated,
  }) : super(key: key);

  @override
  State<NewsSummaryCardWidget> createState() => _NewsSummaryCardWidgetState();
}

class _NewsSummaryCardWidgetState extends State<NewsSummaryCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sentimentAnimController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _sentimentAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Auto-generate summary if not already present
    if (widget.news.summaryBullets.isEmpty && !widget.news.isLoadingSummary) {
      _generateSummary();
    }

    _sentimentAnimController.forward();
  }

  Future<void> _generateSummary() async {
    try {
      final gemini = GeminiService();
      final bullets = await gemini.generateNewsSummary(widget.news.content);
      widget.onSummaryGenerated?.call(bullets);
    } catch (e) {
      print('Error generating summary: $e');
    }
  }

  @override
  void dispose() {
    _sentimentAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF313131),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Source + Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dogonomics logo watermark
                Opacity(
                  opacity: 0.05,
                  child: Text('🐕', style: TextStyle(fontSize: 32)),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.news.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.news.source,
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatDate(widget.news.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Sentiment Gauge
            _buildSentimentGauge(),

            SizedBox(height: 12),

            // Summary Bullets
            _isExpanded
                ? _buildExpandedSummary()
                : _buildCollapsedSummary(),

            SizedBox(height: 12),

            // Read More Button
            ElevatedButton(
              onPressed: widget.onReadMore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded ? 'Close Article' : 'Read Full Article',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.arrow_forward,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentGauge() {
    final percentage = ((widget.news.sentimentScore + 1) / 2 * 100).clamp(0, 100);
    final isPositive = widget.news.sentimentLabel == 'positive';
    final isNegative = widget.news.sentimentLabel == 'negative';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sentiment:',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFB0B0B0),
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : isNegative
                        ? const Color(0xFFF44336).withOpacity(0.2)
                        : const Color(0xFF9E9E9E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isPositive
                      ? const Color(0xFF4CAF50)
                      : isNegative
                          ? const Color(0xFFF44336)
                          : const Color(0xFF9E9E9E),
                  width: 0.5,
                ),
              ),
              child: Text(
                widget.news.sentimentLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPositive
                      ? const Color(0xFF4CAF50)
                      : isNegative
                          ? const Color(0xFFF44336)
                          : const Color(0xFF9E9E9E),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${(widget.news.sentimentConfidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFB0B0B0),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Animated sentiment bar
        ScaleTransition(
          scale: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _sentimentAnimController, curve: Curves.easeOut),
          ),
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFF424242),
              valueColor: AlwaysStoppedAnimation<Color>(
                isPositive
                    ? const Color(0xFF4CAF50)
                    : isNegative
                        ? const Color(0xFFF44336)
                        : const Color(0xFF9E9E9E),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        if (widget.news.isLoadingSummary)
          _buildLoadingSkeleton()
        else if (widget.news.summaryError != null)
          Text(
            '❌ ${widget.news.summaryError}',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFFF44336),
            ),
          )
        else if (widget.news.summaryBullets.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final bullet in widget.news.summaryBullets.take(2))
                if (bullet.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•',
                          style: TextStyle(
                            color: const Color(0xFF66BB6A),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bullet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFFB0B0B0),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (widget.news.summaryBullets.length > 2)
                Text(
                  '... and 1 more',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF757575),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          )
        else
          Text(
            'Tap to generate summary',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF757575),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Summary',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        if (widget.news.isLoadingSummary)
          _buildLoadingSkeleton()
        else if (widget.news.summaryBullets.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < widget.news.summaryBullets.length; i++)
                if (widget.news.summaryBullets[i].isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2E7D32),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.news.summaryBullets[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFE0E0E0),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
