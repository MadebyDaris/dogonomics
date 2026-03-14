import 'package:flutter/material.dart';
import '../backend/gemini_service.dart';
import '../utils/constant.dart';

/// "Explain This" tooltip widget for financial metrics
/// Shows info icon, on tap displays LLM-generated explanation in modal
/// Caches explanations to avoid repeated API calls
class ExplainTooltipWidget extends StatefulWidget {
  final String metricName;
  final String? metricValue;
  final double? iconSize;
  final Color? iconColor;

  const ExplainTooltipWidget({
    Key? key,
    required this.metricName,
    this.metricValue,
    this.iconSize = 16,
    this.iconColor,
  }) : super(key: key);

  @override
  State<ExplainTooltipWidget> createState() => _ExplainTooltipWidgetState();
}

class _ExplainTooltipWidgetState extends State<ExplainTooltipWidget> {
  String? _explanation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-load explanation on widget creation
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    if (_explanation != null) return; // Already loaded

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gemini = GeminiService();
      final explanation = await gemini.explainMetric(
        widget.metricName,
        widget.metricValue,
      );
      if (mounted) {
        setState(() {
          _explanation = explanation;
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

  void _showExplanationModal() {
    if (_explanation == null && !_isLoading && _error == null) {
      _loadExplanation();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildExplanationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showExplanationModal,
      child: Tooltip(
        message: 'Learn more about ${widget.metricName}',
        child: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.iconColor ?? const Color(0xFF66BB6A)).withOpacity(0.1),
          ),
          child: Icon(
            Icons.info_outline,
            size: widget.iconSize,
            color: widget.iconColor ?? const Color(0xFF66BB6A),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationModal() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.metricName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dogonomics logo watermark
                  Opacity(
                    opacity: 0.1,
                    child: Text('🐕', style: TextStyle(fontSize: 48)),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Current value (if provided)
              if (widget.metricValue != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Value',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.metricValue!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),

              // Explanation content
              Text(
                'Explanation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 12),

              if (_isLoading)
                _buildLoadingState()
              else if (_error != null)
                _buildErrorState()
              else if (_explanation != null)
                _buildExplanationContent()
              else
                Text(
                  'Tap to load explanation',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),

              SizedBox(height: 24),

              // Close button
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationContent() {
    return Text(
      _explanation!,
      style: TextStyle(
        fontSize: 14,
        color: const Color(0xFFE0E0E0),
        height: 1.6,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          color: const Color(0xFFF44336),
          size: 24,
        ),
        SizedBox(height: 12),
        Text(
          'Unable to load explanation',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFFF44336),
          ),
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loadExplanation,
          icon: Icon(Icons.refresh, size: 16),
          label: Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }
}

/// Helper widget to add explain tooltip to any metric display
/// Usage: ExplainMetricWidget(
///   label: 'P/E Ratio',
///   value: '25.3',
///   explanation: ExplainTooltipWidget(metricName: 'P/E Ratio', metricValue: '25.3'),
/// )
class ExplainMetricWidget extends StatelessWidget {
  final String label;
  final String value;
  final Widget? explanation; // ExplainTooltipWidget
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const ExplainMetricWidget({
    Key? key,
    required this.label,
    required this.value,
    this.explanation,
    this.labelStyle,
    this.valueStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: labelStyle ??
                  TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
            ),
            if (explanation != null) ...[
              SizedBox(width: 6),
              explanation!,
            ],
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
      ],
    );
  }
}
