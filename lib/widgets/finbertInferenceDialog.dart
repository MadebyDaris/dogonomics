import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:flutter/material.dart';

/// Dialog for running FinBERT sentiment analysis on custom text
class FinBertInferenceDialog extends StatefulWidget {
  const FinBertInferenceDialog({Key? key}) : super(key: key);

  @override
  _FinBertInferenceDialogState createState() => _FinBertInferenceDialogState();
}

class _FinBertInferenceDialogState extends State<FinBertInferenceDialog> {
  final TextEditingController _textController = TextEditingController();
  bool isAnalyzing = false;
  BERTSentiment? result;
  String? error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        error = 'Please enter some text to analyze';
      });
      return;
    }

    setState(() {
      isAnalyzing = true;
      error = null;
      result = null;
    });

    try {
      final sentiment = await DogonomicsAPI.runFinBertInference(text);
      if (mounted) {
        setState(() {
          result = sentiment;
          isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isAnalyzing = false;
        });
      }
    }
  }

  Color _getSentimentColor(String label) {
    switch (label.toLowerCase()) {
      case 'positive':
        return COLOR_POSITIVE;
      case 'negative':
        return COLOR_NEGATIVE;
      default:
        return COLOR_WARNING;
    }
  }

  IconData _getSentimentIcon(String label) {
    switch (label.toLowerCase()) {
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
    return Dialog(
      backgroundColor: CARD_BACKGROUND,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined, color: ACCENT_GREEN, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FinBERT Sentiment Analysis',
                      style: HEADING_MEDIUM,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: TEXT_SECONDARY),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analyze the sentiment of financial text using AI',
                      style: BODY_SECONDARY,
                    ),
                    const SizedBox(height: 24),
                    
                    // Text input
                    Text('Enter text to analyze:', style: BODY_PRIMARY),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      maxLines: 5,
                      style: BODY_PRIMARY,
                      decoration: InputDecoration(
                        hintText: 'e.g., "Apple reported strong quarterly earnings beating analyst expectations..."',
                        hintStyle: BODY_SECONDARY,
                        filled: true,
                        fillColor: APP_BACKGROUND,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: BORDER_COLOR),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: BORDER_COLOR),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: ACCENT_GREEN, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Analyze button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ACCENT_GREEN,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isAnalyzing ? null : _runAnalysis,
                        child: isAnalyzing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Analyzing...'),
                                ],
                              )
                            : const Text('Analyze Sentiment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Results
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: COLOR_NEGATIVE.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: COLOR_NEGATIVE.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: COLOR_NEGATIVE),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                error!,
                                style: BODY_PRIMARY.copyWith(color: COLOR_NEGATIVE),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (result != null)
                      _buildResults(result!)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics_outlined, size: 64, color: TEXT_DISABLED),
                              const SizedBox(height: 12),
                              Text('Enter text and click Analyze', style: BODY_SECONDARY),
                            ],
                          ),
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

  Widget _buildResults(BERTSentiment sentiment) {
    final color = _getSentimentColor(sentiment.label);
    final icon = _getSentimentIcon(sentiment.label);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND_ELEVATED,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentiment header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sentiment', style: CAPTION_TEXT),
                    Text(
                      sentiment.label.toUpperCase(),
                      style: HEADING_SMALL.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Metrics
          _buildMetricRow('Confidence', '${(sentiment.confidence * 100).toStringAsFixed(1)}%', 
              _getConfidenceColor(sentiment.confidence)),
          const SizedBox(height: 12),
          _buildMetricRow('Score', sentiment.score.toStringAsFixed(4), color),
          const SizedBox(height: 20),
          
          // Confidence bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confidence Level', style: CAPTION_TEXT),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sentiment.confidence,
                  backgroundColor: TEXT_DISABLED.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(sentiment.confidence)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: COLOR_INFO.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: COLOR_INFO.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: COLOR_INFO, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analyzed using DoggoFinBERT - a specialized financial sentiment model',
                    style: CAPTION_TEXT.copyWith(color: COLOR_INFO),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BODY_SECONDARY),
        Text(
          value,
          style: BODY_PRIMARY.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return COLOR_POSITIVE;
    } else if (confidence >= 0.6) {
      return COLOR_WARNING;
    } else {
      return COLOR_NEGATIVE;
    }
  }
}

/// Standalone page version for FinBERT inference
class FinBertInferencePage extends StatelessWidget {
  const FinBertInferencePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: APP_BACKGROUND,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TEXT_PRIMARY),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('FinBERT Analysis', style: HEADING_MEDIUM),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _FinBertInferenceContent(),
      ),
    );
  }
}

class _FinBertInferenceContent extends StatefulWidget {
  @override
  _FinBertInferenceContentState createState() => _FinBertInferenceContentState();
}

class _FinBertInferenceContentState extends State<_FinBertInferenceContent> {
  final TextEditingController _textController = TextEditingController();
  bool isAnalyzing = false;
  BERTSentiment? result;
  String? error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        error = 'Please enter some text to analyze';
      });
      return;
    }

    setState(() {
      isAnalyzing = true;
      error = null;
      result = null;
    });

    try {
      final sentiment = await DogonomicsAPI.runFinBertInference(text);
      if (mounted) {
        setState(() {
          result = sentiment;
          isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isAnalyzing = false;
        });
      }
    }
  }

  Color _getSentimentColor(String label) {
    switch (label.toLowerCase()) {
      case 'positive':
        return COLOR_POSITIVE;
      case 'negative':
        return COLOR_NEGATIVE;
      default:
        return COLOR_WARNING;
    }
  }

  IconData _getSentimentIcon(String label) {
    switch (label.toLowerCase()) {
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CARD_BACKGROUND,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BORDER_COLOR),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined, color: ACCENT_GREEN, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Sentiment Analysis', style: HEADING_SMALL),
                      const SizedBox(height: 4),
                      Text(
                        'Analyze financial text sentiment using DoggoFinBERT',
                        style: BODY_SECONDARY,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text('Enter Financial Text', style: HEADING_SMALL),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 8,
            style: BODY_PRIMARY,
            decoration: InputDecoration(
              hintText: 'e.g., "Apple reported strong quarterly earnings beating analyst expectations with revenue growth of 15%..."',
              hintStyle: BODY_SECONDARY,
              filled: true,
              fillColor: CARD_BACKGROUND,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BORDER_COLOR),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BORDER_COLOR),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ACCENT_GREEN, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ACCENT_GREEN,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isAnalyzing ? null : _runAnalysis,
              child: isAnalyzing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Analyzing...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics),
                        const SizedBox(width: 8),
                        const Text('Analyze Sentiment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: COLOR_NEGATIVE.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: COLOR_NEGATIVE.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: COLOR_NEGATIVE),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error!,
                      style: BODY_PRIMARY.copyWith(color: COLOR_NEGATIVE),
                    ),
                  ),
                ],
              ),
            )
          else if (result != null)
            _buildResults(result!)
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: CARD_BACKGROUND,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BORDER_COLOR),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.analytics_outlined, size: 64, color: TEXT_DISABLED),
                    const SizedBox(height: 12),
                    Text('Enter text above and click Analyze', style: BODY_SECONDARY),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(BERTSentiment sentiment) {
    final color = _getSentimentColor(sentiment.label);
    final icon = _getSentimentIcon(sentiment.label);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analysis Results', style: HEADING_SMALL),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sentiment Classification', style: CAPTION_TEXT),
                    const SizedBox(height: 4),
                    Text(
                      sentiment.label.toUpperCase(),
                      style: HEADING_LARGE.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildMetricCard('Confidence Level', '${(sentiment.confidence * 100).toStringAsFixed(1)}%', 
              _getConfidenceColor(sentiment.confidence), sentiment.confidence),
          const SizedBox(height: 16),
          _buildMetricCard('Sentiment Score', sentiment.score.toStringAsFixed(4), color, null),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: COLOR_INFO.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: COLOR_INFO.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: COLOR_INFO, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Powered by DoggoFinBERT - a fine-tuned BERT model specialized for financial sentiment analysis',
                    style: CAPTION_TEXT.copyWith(color: COLOR_INFO),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color valueColor, double? progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND_ELEVATED,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: BODY_SECONDARY),
              Text(
                value,
                style: HEADING_SMALL.copyWith(color: valueColor),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: TEXT_DISABLED.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(valueColor),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return COLOR_POSITIVE;
    } else if (confidence >= 0.6) {
      return COLOR_WARNING;
    } else {
      return COLOR_NEGATIVE;
    }
  }
}
