import 'package:flutter/material.dart';
import '../backend/gemini_service.dart';

class DoggoInlineInsightWidget extends StatefulWidget {
  final String context;
  final String prompt;

  const DoggoInlineInsightWidget({
    Key? key,
    required this.context,
    required this.prompt,
  }) : super(key: key);

  @override
  State<DoggoInlineInsightWidget> createState() => _DoggoInlineInsightWidgetState();
}

class _DoggoInlineInsightWidgetState extends State<DoggoInlineInsightWidget> {
  String? _insightText;
  bool _isLoading = false;

  void _fetchInsight() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await GeminiService().generateChatResponse(
        widget.prompt,
        stockSymbol: widget.context,
      );
      if (mounted) {
        setState(() {
          _insightText = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _insightText = 'Doggo is currently resting. Try again later!';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF313131)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: Color(0xFF66BB6A), size: 24),
              const SizedBox(width: 8),
              const Text(
                'Doggo Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_insightText == null && !_isLoading)
                TextButton.icon(
                  onPressed: _fetchInsight,
                  icon: const Icon(Icons.flash_on, size: 16, color: Color(0xFF66BB6A)),
                  label: const Text('Generate', style: TextStyle(color: Color(0xFF66BB6A))),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF262626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF66BB6A)),
                ),
              ),
            ),
          if (_insightText != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                _insightText!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE0E0E0),
                  height: 1.5,
                ),
              ),
            ),
          if (_insightText == null && !_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Get quick AI analysis and contextual advice based on the current market view.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
