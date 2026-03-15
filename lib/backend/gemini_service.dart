import 'package:google_generative_ai/google_generative_ai.dart';

/// GeminiService provides LLM-powered features:
/// - News summary generation (3-bullet summaries)
/// - Metric/concept explanations ("Explain This" tooltips)
/// - Chat responses for market questions
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  
  late GenerativeModel _model;
  final Map<String, String> _explanationCache = {}; // Cache explanations
  bool _isInitialized = false;

  GeminiService._internal();

  factory GeminiService() {
    return _instance;
  }

  /// Initialize the Gemini service with API key
  /// Call this once in main.dart before using any GeminiService methods
  Future<void> initialize(String apiKey) async {
    if (_isInitialized) return;
    
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Use flash for speed (cheaper than pro)
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  /// Generate a 3-bullet summary of a news article
  /// Input: Full article text
  /// Output: List of 3 bullet points summarizing key points
  Future<List<String>> generateNewsSummary(String articleText) async {
    if (!_isInitialized) throw Exception('GeminiService not initialized');
    
    try {
      final prompt = '''Summarize this news article in exactly 3 bullet points. Each bullet should be:
- One sentence (10-15 words max)
- Focus on the key information
- Written for a financial audience

Article:
$articleText

Return ONLY the 3 bullets, one per line, starting with "•". Do not add extra text.''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        return ['Unable to generate summary', '', ''];
      }

      // Parse bullets from response
      final bullets = response.text!
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(3)
          .map((line) => line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
          .toList();

      // Pad to 3 if fewer returned
      while (bullets.length < 3) {
        bullets.add('');
      }

      return bullets.sublist(0, 3);
    } catch (e) {
      print('Error generating news summary: $e');
      return ['Summary unavailable', '', ''];
    }
  }

  /// Generate an explanation for a financial metric or concept
  /// Explanations are cached to avoid repeated API calls
  /// Input: Metric name (e.g., "P/E Ratio", "Market Cap")
  /// Output: 1-2 sentence explanation suitable for a tooltip
  Future<String> explainMetric(String metricName, [String? metricValue]) async {
    if (!_isInitialized) throw Exception('GeminiService not initialized');

    // Check cache first
    final cacheKey = metricName.toLowerCase();
    if (_explanationCache.containsKey(cacheKey)) {
      return _explanationCache[cacheKey]!;
    }

    try {
      final valueHint = metricValue != null ? ' (current value: $metricValue)' : '';
      final prompt = '''Explain this financial metric in 1-2 sentences for a beginner investor:

Metric: $metricName$valueHint

Requirements:
- 1-2 sentences maximum
- Simple, clear language
- Explain what it measures and why it matters
- Do not include formulas or equations

Response:''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final explanation = response.text?.trim() ?? 'Explanation unavailable';
      
      // Cache for future use
      _explanationCache[cacheKey] = explanation;
      
      return explanation;
    } catch (e) {
      print('Error explaining metric: $e');
      return 'Unable to explain this metric at this time.';
    }
  }

  /// Generate a chat response for a user question about markets
  /// Optional context: stock symbol, current price, sentiment data
  /// Returns: LLM-generated response
  Future<String> generateChatResponse(
    String userMessage, {
    String? stockSymbol,
    double? currentPrice,
    String? sentimentData,
  }) async {
    if (!_isInitialized) throw Exception('GeminiService not initialized');

    try {
      String contextStr = '';
      if (stockSymbol != null) {
        contextStr = 'User is asking about $stockSymbol';
        if (currentPrice != null) {
          contextStr += ' (current price: \$$currentPrice)';
        }
        if (sentimentData != null) {
          contextStr += ' with sentiment: $sentimentData';
        }
        contextStr += '\n\n';
      }

      final prompt = '''You are Dogonomics, a helpful AI assistant for retail investors and market enthusiasts. 
You provide clear, actionable market insights without giving specific investment advice.

${contextStr}User question: $userMessage

Respond in 1-2 paragraphs, keeping it conversational and helpful. Focus on market dynamics, not individual recommendations.''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'I could not generate a response. Please try again.';
    } catch (e) {
      print('Error generating chat response: $e');
      return 'Sorry, I encountered an error. Please try again.';
    }
  }

  /// Stream a chat response character-by-character (for typing effect in UI)
  /// Returns: Stream<String> emitting chunks of the response
  Stream<String> streamChatResponse(
    String userMessage, {
    String? stockSymbol,
    double? currentPrice,
    String? sentimentData,
  }) async* {
    if (!_isInitialized) {
      yield 'Error: GeminiService not initialized';
      return;
    }

    try {
      String contextStr = '';
      if (stockSymbol != null) {
        contextStr = 'User is asking about $stockSymbol';
        if (currentPrice != null) {
          contextStr += ' (current price: \$$currentPrice)';
        }
        if (sentimentData != null) {
          contextStr += ' with sentiment: $sentimentData';
        }
        contextStr += '\n\n';
      }

      final prompt = '''You are Dogonomics, a helpful AI assistant for retail investors and market enthusiasts.
You provide clear, actionable market insights without giving specific investment advice.

${contextStr}User question: $userMessage

Respond in 1-2 paragraphs, keeping it conversational and helpful.''';

      final content = [Content.text(prompt)];
      
      await for (final chunk in _model.generateContentStream(content)) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  /// Clear the explanation cache (useful if you want to refresh all explanations)
  void clearCache() {
    _explanationCache.clear();
  }

  /// Get cache statistics (useful for debugging)
  Map<String, int> getCacheStats() {
    return {
      'cached_explanations': _explanationCache.length,
    };
  }
}
