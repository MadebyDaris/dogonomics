import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:Dogonomics/widgets/doggo_inline_insight.dart';

class NewsArticleDetailPage extends StatelessWidget {
  final NewsItem newsItem;

  const NewsArticleDetailPage({Key? key, required this.newsItem}) : super(key: key);

  Color _getSentimentColor() {
    switch (newsItem.bertSentiment.label.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSentimentIcon() {
    switch (newsItem.bertSentiment.label.toLowerCase()) {
      case 'positive':
        return Icons.trending_up;
      case 'negative':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _getSentimentColor();

    return Scaffold(
      backgroundColor: BACKG_COLOR,
      appBar: AppBar(
        backgroundColor: MAINGREY,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Article Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sentiment Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    sentimentColor.withOpacity(0.3),
                    sentimentColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: sentimentColor,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sentimentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSentimentIcon(),
                      color: sentimentColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sentiment: ${newsItem.bertSentiment.label.toUpperCase()}',
                          style: TextStyle(
                            color: sentimentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: ${(newsItem.bertSentiment.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Score: ${newsItem.bertSentiment.score.toStringAsFixed(3)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Article Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        newsItem.date,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    newsItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          sentimentColor.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Content
                  Text(
                    newsItem.content,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 32),

                  DoggoInlineInsightWidget(
                    context: 'Article Summarizer',
                    prompt: 'Summarize the following financial news article and extract 3 key takeaways. Article Title: ${newsItem.title}. Content: ${newsItem.content}',
                  ),
                  const SizedBox(height: 32),

                  // Sentiment Analysis Details
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Icon(
                              Icons.psychology,
                              color: sentimentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Sentiment Analysis',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAnalysisRow(
                          'Classification',
                          newsItem.bertSentiment.label.toUpperCase(),
                          sentimentColor,
                        ),
                        const SizedBox(height: 8),
                        _buildAnalysisRow(
                          'Confidence Level',
                          '${(newsItem.bertSentiment.confidence * 100).toStringAsFixed(1)}%',
                          _getConfidenceColor(newsItem.bertSentiment.confidence),
                        ),
                        const SizedBox(height: 8),
                        _buildAnalysisRow(
                          'Sentiment Score',
                          newsItem.bertSentiment.score.toStringAsFixed(3),
                          sentimentColor,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[300],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Analyzed using DoggoFinBERT - a specialized financial sentiment model',
                                  style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, Color valueColor) {
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
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
