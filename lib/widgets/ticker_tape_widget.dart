import 'package:flutter/material.dart';
import '../backend/models.dart';
import '../backend/providers.dart';
import '../utils/constant.dart';

/// Live scrolling ticker tape displaying market sentiment
/// Shows real-time sentiment from Reddit and news sources
/// Automatically scrolls horizontally, sentiment colors update reactively
class TickerTapeWidget extends StatefulWidget {
  final TickerProvider tickerProvider;
  final VoidCallback? onSymbolTap;

  const TickerTapeWidget({
    Key? key,
    required this.tickerProvider,
    this.onSymbolTap,
  }) : super(key: key);

  @override
  State<TickerTapeWidget> createState() => _TickerTapeWidgetState();
}

class _TickerTapeWidgetState extends State<TickerTapeWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  final Map<String, AnimationController> _flashAnimations = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Auto-scroll ticker horizontally
    _startAutoScroll();

    // Listen for new ticker items and trigger animations
    widget.tickerProvider.addListener(_onTickerUpdated);
  }

  void _startAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _animateScroll();
      }
    });
  }

  void _animateScroll() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(seconds: 20),
      curve: Curves.linear,
    ).then((_) {
      _scrollController.jumpTo(0);
      _animateScroll();
    }).catchError((_) {
      // Handle scroll errors
    });
  }

  void _onTickerUpdated() {
    setState(() {
      // Trigger flash animation for the newest item
      if (widget.tickerProvider.ticker.isNotEmpty) {
        final newestSymbol = widget.tickerProvider.ticker.first.symbol;
        _triggerFlash(newestSymbol);
      }
    });
  }

  void _triggerFlash(String symbol) {
    if (!_flashAnimations.containsKey(symbol)) {
      _flashAnimations[symbol] = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    }

    _flashAnimations[symbol]!.forward(from: 0.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    for (var controller in _flashAnimations.values) {
      controller.dispose();
    }
    widget.tickerProvider.removeListener(_onTickerUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.tickerProvider.isConnected && widget.tickerProvider.ticker.isEmpty) {
      return _buildOfflineState();
    }

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF313131),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A1A),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Dogonomics watermark logo
          Positioned(
            right: 16,
            top: 4,
            child: Opacity(
              opacity: 0.1,
              child: Text(
                '🐕',
                style: TextStyle(fontSize: 48),
              ),
            ),
          ),

          // Horizontal scrolling ticker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollController,
            child: Row(
              children: widget.tickerProvider.ticker
                  .map((item) => _buildTickerItem(item))
                  .toList(),
            ),
          ),

          // Connection status indicator
          Positioned(
            left: 8,
            top: 4,
            child: _buildConnectionIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerItem(TickerItem item) {
    final flashAnimation = _flashAnimations[item.symbol];
    final isPositive = item.sentimentLabel == 'positive';
    final isNegative = item.sentimentLabel == 'negative';

    return AnimatedBuilder(
      animation: flashAnimation ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        // Flash color based on sentiment
        final baseColor = isPositive
            ? const Color(0xFF4CAF50).withOpacity(0.15) // Green
            : isNegative
                ? const Color(0xFFF44336).withOpacity(0.15) // Red
                : const Color(0xFF9E9E9E).withOpacity(0.1); // Gray

        final flashColor = isPositive
            ? const Color(0xFF4CAF50).withOpacity(0.4)
            : isNegative
                ? const Color(0xFFF44336).withOpacity(0.4)
                : const Color(0xFF9E9E9E).withOpacity(0.2);

        // Interpolate background during flash
        final animValue = flashAnimation?.value ?? 0.0;
        final bgColor = Color.lerp(flashColor, baseColor, animValue) ?? baseColor;

        return GestureDetector(
          onTap: () => widget.onSymbolTap?.call(),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPositive
                    ? const Color(0xFF4CAF50)
                    : isNegative
                        ? const Color(0xFFF44336)
                        : const Color(0xFF9E9E9E),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Symbol + Sentiment Badge
                Row(
                  children: [
                    Text(
                      item.symbol,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFF4CAF50)
                            : isNegative
                                ? const Color(0xFFF44336)
                                : const Color(0xFF9E9E9E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPositive ? '↑' : isNegative ? '↓' : '→',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      item.sourceBadge,
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                // Confidence indicator
                Text(
                  '${(item.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineState() {
    return Container(
      height: 80,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Market Ticker Offline',
              style: TextStyle(
                color: const Color(0xFF9E9E9E),
                fontSize: 12,
              ),
            ),
            if (widget.tickerProvider.error != null)
              Text(
                widget.tickerProvider.error!,
                style: TextStyle(
                  color: const Color(0xFFF44336),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    final isConnected = widget.tickerProvider.isConnected;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        boxShadow: [
          if (isConnected)
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }
}
