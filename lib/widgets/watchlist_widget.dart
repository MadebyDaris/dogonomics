import 'package:flutter/material.dart';
import '../utils/constant.dart';
import '../utils/tickerData.dart';

class WatchlistWidget extends StatefulWidget {
  final List<String> symbols;

  const WatchlistWidget({super.key, required this.symbols});

  @override
  State<WatchlistWidget> createState() => _WatchlistWidgetState();
}

class _WatchlistWidgetState extends State<WatchlistWidget> {
  Map<String, LiveQuote?> quotes = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    Map<String, LiveQuote?> fetchedQuotes = {};
    for (var symbol in widget.symbols) {
      final quote = await fetchLiveQuote(symbol);
      fetchedQuotes[symbol] = quote;
    }
    if (mounted) {
      setState(() {
        quotes = fetchedQuotes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.symbols.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Now',
                style: HEADING_MEDIUM,
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.symbols.length,
            itemBuilder: (context, index) {
              final symbol = widget.symbols[index];
              final quote = quotes[symbol];
              return _buildWatchlistCard(symbol, quote);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWatchlistCard(String symbol, LiveQuote? quote) {
    double change = 0.0;
    double percentChange = 0.0;
    Color color = TEXT_SECONDARY;

    if (quote != null) {
      change = quote.current - quote.previousClose;
      percentChange = (change / quote.previousClose) * 100;
      color = change >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE;
    }

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(borderColor: BORDER_COLOR_LIGHT),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                symbol,
                style: const TextStyle(
                  color: TEXT_PRIMARY,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (quote == null)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (quote != null) ...[
            Text(
              quote.current.toStringAsFixed(2),
              style: const TextStyle(
                color: TEXT_PRIMARY,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Icon(
                  change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${percentChange.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
