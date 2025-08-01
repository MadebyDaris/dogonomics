class LiveQuote {
  final String symbol;
  final double current;
  final double high;
  final double low;
  final double open;
  final double previousClose;

  LiveQuote({
    required this.symbol,
    required this.current,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
  });

  factory LiveQuote.fromJson(Map<String, dynamic> json) {
    return LiveQuote(
      symbol: json['symbol'],
      current: (json['c'] as num).toDouble(),
      high: (json['h'] as num).toDouble(),
      low: (json['l'] as num).toDouble(),
      open: (json['o'] as num).toDouble(),
      previousClose: (json['pc'] as num).toDouble(),
    );
  }
}